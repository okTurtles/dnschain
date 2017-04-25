###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

###

INSTRUCTIONS:

    1. Copy this file and rename it to your blockchain's name.
       The name you choose will also be your metaTLD (e.g. namecoin.coffee => namecoin.dns)
    2. Rename the class (following the same naming convention as shown in
       `blockchains/namecoin.coffee`) and `extend BlockchainResolver`
    3. Uncomment and edit the code as appropriate.
       Look at how the other blockchains do it (especially namecoin.coffee)

    REMEMBER: When in doubt, look at `blockchains/namecoin.coffee` !

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # Uncomment this:
    # BlockchainResolver = require('../blockchain.coffee')(dnschain)

    # For `dnsHandler:`
    ResolverStream  = require('./resolver-stream')(dnschain)
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    # This class is partially annotated using flowtate
    # http://flowtype.org/blog/2015/02/20/Flow-Comments.html
    # https://github.com/jareware/flotate
    ### @flow ###

                             # Uncomment the 'extends' comment below:
    class BlockchainResolver # extends BlockchainResolver
        # Do you initialization in here.
        ### (dnschain: DNSChain): BlockchainResolver ###
        constructor: (@dnschain) ->
            # Fill these in as appropriate:
            @log = gNewLogger 'YourChainName'
            @tld = 'chn'            # Your chain's TLD
            @name = 'templatechain' # Your chain's name (lowercase, no spaces)

            # Optionally specify how long Redis should cache entries in seconds
            # @cacheTTL = 600         # 0 == no cache, override here

            # Fills this object with `startCheck` and `shutdownCheck` methods
            gFillWithRunningChecks @

        # This is the default TTL value for all blockchains.
        # Override it above in the constructor for your blockchain.
        cacheTTL: gConf.get 'redis:blockchain:ttl'

        # Return `this` upon successful load, falsy otherwise
        # If you return `this`, this chain will be included in the parent
        # DNSChain instance's `@servers` list, and will have its `start:`
        # method called.
        ### : ?(BlockchainResolver | boolean) ###
        config: ->
            @log.debug "Loading resolver config"
            @
            # Fill this in with code to load your config.
            # We recommend copying and editing the stuff from namecoin.coffee
            #
            # if "loaded successfully"
            #     return this
            # else
            #     return false

        # Connect to your blockchain. Return a Promise
        ### : Promise ###
        start: ->
            # Replace this with something useful.
            # 'cb' is of the form (err, args...) ->
            @startCheck (cb) => cb null

        # Close connection to your blockchain and do any other cleanup. Return a Promise.
        ### : Promise ###
        shutdown: ->
            # Replace this with something useful.
            # 'cb' is of the form (err, args...) ->
            @shutdownCheck (cb) => cb null


        # Do not modify the result template itself. Instead, set its .data property
        # in your resources.key function.See how other blockchains do it.
        ### : object ###
        resultTemplate: ->
            version: '0.0.1'
            header:
                datastore: @name
            data: {} # <== Your `resources.key` function *must* set this to a JSON
                     #     object that contains the output from your blockchain.

        standardizers:
            # These Functions convert data in the `data` object (see `resultTemplate` above)
            # into a standard form (primarily for processing by `dnsHandler`s.
            # See nxt.coffee for example of how to override.
            dnsInfo: (data) -> data.value # Value sould conform to Namecoin's d/ spec.
            ttlInfo: (data) -> 600 # 600 seconds for Namecoin (override if necessary)

        # Any valid resource for a blockchain should be set here.
        # All keys of this object must be functions of this form:
        #   (property: string, operation: string, fmt: string, args: object, cb: function(err: object, result: object)) ->
        #
        # For more information, see:
        #   https://github.com/okTurtles/openname-specifications/blob/resolvers/resolvers.md
        resources:
            key: (property, operation, fmt, args, cb) ->
                cb new Error "Not Implemented"
                # Example of what this function should do.
                # Uncomment and edit:
                #result = @resultTemplate()

                # myBlockchain.resolve path, (err, answer) =>
                #     if err
                #         cb err
                #     else
                #         result.data = JSON.parse answer
                #         cb null, result

        dnsHandler: # A dictionary of functions corresponding to traditional DNS.
            # You DO NOT need to copy these functions over unless you want to customize
            # them for your blockchain. By default, these are designed for Namecoin's d/ spec. 
            # Value of `this` is bound to the class instance (i.e. you blockchain).
            # TODO: handle all the types specified in the specification!
            #       https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Value_field
            #
            # TODO: handle other info outside of the specification!
            #       - GNS support
            #       - DNSSEC support?
            # Functions must be of this function signature
            ### (object, object, number, object, function): any ###
            A: (req, res, qIdx, data, cb) ->
                q = req.question[qIdx]
                @log.debug gLineInfo "A handler for #{@name}", {q:q}
                info = @standardizers.dnsInfo data
                ttl = @standardizers.ttlInfo data

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

                    nsIPs = gES.merge(gES.readArray(nsIPs), gES.readArray(nsCNAMEs).pipe(nsCNAME2IP))

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
                q = req.question[qIdx]
                @log.debug gLineInfo "AAAA handler for #{@name}", {q:q}
                info = @standardizers.dnsInfo data
                ttl = @standardizers.ttlInfo data

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

                    nsIPs = gES.merge(gES.readArray(nsIPs), gES.readArray(nsCNAMEs).pipe(nsCNAME2IP))

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

                else if info.ip6
                    # we have its IP! send reply to client
                    # TODO: handle more info! send the rest of the
                    #       stuff in 'info', and all the IPs!
                    info.ip6 = [info.ip6] if typeof info.ip6 is 'string'
                    # info.ip.forEach (a)-> res.answer.push gIP2type(q.name, ttl)(a)
                    res.answer.push (info.ip6.map gIP2type(q.name, ttl, 'AAAA'))...
                    cb()
                else
                    @log.warn gLineInfo('no useful data from nmc_show'), {q:q}
                    cb NAME_RCODE.NOTFOUND
            # /end 'AAAA'

            TLSA: (req, res, qIdx, data, cb) ->
                q = req.question[qIdx]
                @log.debug gLineInfo "TLSA handler for #{@name}", {q:q}
                ttl = @standardizers.ttlInfo data
                len = res.answer.length
                if info = @standardizers.dnsInfo data
                    res.answer.push gTls2tlsa(info.tls, ttl, q.name)...
                # check if any records were added
                if res.answer.length - len is 0
                    @log.warn gLineInfo('no TLSA found'), {q:q, data:data}
                    cb NAME_RCODE.NOTFOUND
                else
                    cb()

            ANY: ->
                @log.debug gLineInfo "ANY handler for #{@name}"
                # TODO: loop through dnsInfo and call approrpriate handlers
                # TODO: enable EDNS reply
                @dnsHandler.A.apply @, [].slice.call arguments
