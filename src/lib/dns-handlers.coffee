###

dnschain
http://dnschain.net

Copyright (c) 2013-2014 Greg Slepak

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    ResolverStream  = require('./resolver-stream')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME
    BLOCKS2SEC = 10 * 60

    LOCALHOSTS = _.uniq [
        "127.0.0.", "10.0.0.", "192.168.", "::1", "fe80::"
        gConf.get('dns:host'), gConf.get('http:host')
        gConf.get('dns:externalIP'), gExternalIP()
        gConf.nmc.get('rpcconnect')
    ].filter (o)-> typeof(o) is 'string'

    # instanceNum = 0 # debugging

    # It is the hander's job to add answers to 'res' but *NOT* to send them!
    # Instead, it should call the callback function 'cb'.
    # Pass in a NAME_RCODE to 'cb' on error, or nothing on success.
    # 
    # IMPORTANT: these functions __*MUST*__ be bound to the DNSServer instance 
    #            that calls them!
    dnsTypeHandlers =
        namecoin:
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
                    # IPs like 127.0.0.1 are checked below against LOCALHOSTS array

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
                        if _.find(LOCALHOSTS, (ip)->S(nsIP).startsWith ip)
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