###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    BlockchainResolver = require('../blockchain.coffee')(dnschain)
    ResolverStream  = require('../resolver-stream')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME
    BLOCKS2SEC = 10 * 60

    # Specifications listed here:
    # - https://wiki.namecoin.info/index.php?title=Welcome
    # - https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Importing_and_delegation
    # - https://wiki.namecoin.info/index.php?title=Category:NEP
    # - https://wiki.namecoin.info/index.php?title=Namecoin_Specification
    VALID_NMC_DOMAINS = /^[a-zA-Z]+\/.+/

    class NamecoinResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NMC'
            @name = 'namecoin'
            @tld = 'bit'

        config: ->
            @log.debug "Loading #{@name} resolver"

            gConf.add @name, _.map(_.filter([
                [process.env.APPDATA, 'Namecoin', 'namecoin.conf']
                [process.env.HOME, '.namecoin', 'namecoin.conf']
                [process.env.HOME, 'Library', 'Application Support', 'Namecoin', 'namecoin.conf']
                ['/etc/namecoin/namecoin.conf']]
            , (x) -> !!x[0])
            , (x) -> path.join x...), 'INI'

            # we want them in this exact order:
            params = ["port", "connect", "user", "password"].map (x) => gConf.chains[@name].get 'rpc'+x
            params[1] ?= "127.0.0.1"
            if not _.every params
                @log.info "#{@name} disabled. (namecoin.conf not found, or rpcuser, rpcpassword, rpcport not found)"
                return
            gConf.chains[@name].set 'host', gConf.chains[@name].get('rpcconnect')
            @peer = rpc.Client.$create(params...) or gErr "rpc create"

            # TODO: $create doesn't actually connect. you need to open a raw socket
            #       or an http socket and see if that works before declaring it works
            @log.info "rpc to namecoind on: %s:%d", params[1], params[0]
            @

        shutdown: (cb) ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!
            cb?()

        resolve: (path, options, cb) ->
            result = @resultTemplate()
            if S(path).endsWith(".#{@tld}") # naimcoinize Domain
                path = S(path).chompRight(".#{@tld}").s
                if (dotIdx = path.lastIndexOf('.')) != -1
                    path = path.slice(dotIdx+1) #rm subdomain
                path = 'd/' + path
            @log.debug gLineInfo("#{@name} resolve"), {path:path}
            @peer.call 'name_show', [path], (err, ans) ->
                return cb(err) if err
                try
                    result.value = JSON.parse ans.value
                    cb null, result
                catch e
                    @log.error gLineInfo(e.message)
                    cb e

        validRequest: (path) -> VALID_NMC_DOMAINS.test path

        dnsHandler:
            # TODO: handle all the types specified in the specification!
            #       https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Value_field
            #
            # TODO: handle other info outside of the specification!
            #       - GNS support
            #       - DNSSEC support?
            #
            # *ALL* namecoin handlers must be of the this type
            A: (req, res, qIdx, data, cb) ->
                # @log.warn gLineInfo('debug A handler...'), {data: data}
                info = data.value
                q = req.question[qIdx]
                ttl = BLOCKS2SEC # average block creation time. TODO: make even more accurate value

                # According to NMC specification, specifying 'ns'
                # overrules 'ip' value, so check it here and resolve using
                # old-style DNS.
                if info.ns?.length > 0
                    # 1. Create a stream of nameserver IP addresses out of info.ns
                    # 2. Send request to each of the servers, separated by `stackedDelay`.
                    #    On receiving the first answer from any of them, cancel all other
                    #    pending requests and respond to our client.
                    #
                    # TODO: handle ns = IPv6 addr!
                    [nsIPs, nsCNAMEs] = [[],[]]

                    for ip in info.ns
                        (if net.isIP(ip) then nsIPs else nsCNAMEs).push(ip)

                    if @method is gConsts.oldDNS.NO_OLD_DNS_EVER
                        nsCNAMEs = []

                    # IMPORTANT! This DNSChain server might have a bi-directional relationship
                    #            with another local resolver for oldDNS (like PowerDNS). We
                    #            don't want malicious data in the blockchain to result in
                    #            queries being sent back and forth between them ad-infinitum!
                    #            Namecoin's specification states that these should only be
                    #            oldDNS TLDs anyway. Use 'delegate', 'import', or 'map' to
                    #            refer to other blockchain locations:
                    #            https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Value_field
                    # WARNING!   Because of this issue, it's probably best to not create a
                    #            bi-directional relationship like this between two resolvers.
                    #            It's far safer to tell DNSChain to use a different resolver
                    #            that won't re-ask DNSChain any questions.
                    nsCNAMEs = _.reject nsCNAMEs, (ns)->/\.(bit|dns)$/.test ns
                    # IPs like 127.0.0.1 are checked below against gConf.localhosts array

                    if nsIPs.length == nsCNAMEs.length == 0
                        return cb NAME_RCODE.REFUSED

                    # TODO: use these statically instead of creating new instances for each request
                    #       See: https://github.com/okTurtles/dnschain/issues/11
                    nsCNAME2IP   = new ResolverStream
                        name        : 'nsCNAME2IP' # +'-'+(instanceNum++)
                        stackedDelay: 100
                    stackedQuery = new ResolverStream
                        name        : 'stackedQuery' #+'-'+(instanceNum-1)
                        stackedDelay: 1000
                        reqMaker    : (nsIP) =>
                            dns2.Request
                                question: q
                                server: address: nsIP

                    nsIPs = es.merge(sa(nsIPs), sa(nsCNAMEs).pipe(nsCNAME2IP))

                    stopRequests = (code) =>
                        if code
                            @log.warn gLineInfo("errors on all NS!"), {q:q, code:RCODE_NAME[code]}
                        else
                            @log.debug gLineInfo('ending async requests'), {q:q}
                        rs.cancelRequests(true) for rs in [nsCNAME2IP, stackedQuery]
                        cb code

                    nsIPs.on 'data', (nsIP) =>
                        if _.find(gConf.localhosts, (ip)->S(nsIP).startsWith ip)
                            # avoid the possible infinite-loop on some (perhaps poorly) configured systems
                            @log.warn gLineInfo('dropping query, NMC NS ~= localhost!'), {q:q, nsIP:nsIP, info:info}
                        else
                            stackedQuery.write(nsIP)

                    nsCNAME2IP.on 'failed', (err) =>
                        @log.warn gLineInfo('nsCNAME2IP error'), {error:err?.message, q:q}
                        if nsCNAME2IP.errCount == info.ns.length
                            stopRequests err.code ? NAME_RCODE.NOTFOUND

                    stackedQuery.on 'failed', (err) =>
                        @log.warn gLineInfo('stackedQuery error'), {error:err?.message, q:q}
                        if stackedQuery.errCount == info.ns.length
                            stopRequests err.code ? NAME_RCODE.SERVFAIL

                    stackedQuery.on 'answers', (answers) =>
                        @log.debug gLineInfo('stackedQuery answers'), {answers:answers}
                        res.answer.push answers...
                        stopRequests()

                else if info.ip
                    # we have its IP! send reply to client
                    # TODO: handle more info! send the rest of the
                    #       stuff in 'info', and all the IPs!
                    info.ip = [info.ip] if typeof info.ip is 'string'
                    # info.ip.forEach (a)-> res.answer.push gIP2type(q.name, ttl)(a)
                    res.answer.push (info.ip.map gIP2type(q.name, ttl))...
                    cb()
                else
                    @log.warn gLineInfo('no useful data from nmc_show'), {q:q}
                    cb NAME_RCODE.NOTFOUND
            # /end 'A'

            # TODO: implement this!
            AAAA: (req, res, qIdx, data, cb) ->
                cb NAME_RCODE.NOTIMP

            TLSA: (req, res, qIdx, data, cb) ->
                len = res.answer.length
                ttl = data.expires_in? * BLOCKS2SEC
                q = req.question[qIdx]
                if info = data.value
                    res.answer.push gTls2tlsa(info.tls, ttl, q.name)...
                # check if any records were added
                if res.answer.length - len is 0
                    @log.warn gLineInfo('no TLSA found'), {q:q, data:data}
                    cb NAME_RCODE.NOTFOUND
                else
                    cb()

            ANY: ->
                # TODO: loop through 'data.value' and call approrpriate handlers
                # TODO: enable EDNS reply
                dnsTypeHandlers.namecoin.A.apply @, [].slice.call arguments
