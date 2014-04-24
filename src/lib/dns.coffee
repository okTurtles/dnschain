###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# TODO: go through 'TODO's!
#       
# TODO: check if we're missing any edns support

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    ResolverStream = require('./resolver-stream')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class DNSServer
        constructor: (@dnschain) ->
            @log = newLogger 'DNS'
            @log.debug "Loading DNSServer..."

            # this is just for development testing of NODE_DNS method
            # dns.setServers ['8.8.8.8']
            
            if dns.getServers? and consts.oldDNS.NODE_DNS is config.get 'dns:oldDNSMethod'
                blacklist = _.intersection ['127.0.0.1', '::1', 'localhost'], dns.getServers()
                if blacklist.length > 0
                    tErr "Cannot use NODE_DNS method when system DNS lists %j as a resolver! Would lead to infinite loop!", blacklist

            @server = dns2.createServer() or tErr "dns2 create"
            @server.on 'socketError', (err) -> tErr err
            @server.on 'request', @callback.bind(@)
            @server.serve config.get('dns:port'), config.get('dns:host')

            @log.info 'started DNS', config.get 'dns'

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        # (Notes on 'native-dns' version <=0.6.x, which I'd like to see changed.)
        # 
        # Both `req` and `res` are of type `Packet` (the subclass, as explained next).
        # 
        # The packet that's inside of 'native-dns' inherits from the one inside of 'native-dns-packet'.
        # It adds two extra fields (at this time of writing):
        # 
        # - address: added by Server.prototype.handleMessage and the Packet subclass constructor
        # - _socket: added by the Packet subclass constructor in lib/packet.js
        # 
        # `req` and `res` are both instances of this subclass of 'Packet'.
        # They also have the same 'question' field.
        # 
        # See also:
        # - native-dns/lib/server.js
        # - native-dns/lib/packet.js
        # - native-dns-packet/packet.js
        # 
        # Separately, there is a 'Request' class defined in 'native-dns/lib/client.js'.
        # Like 'Packet', it has a 'send' method.
        # To understand it see these functions in 'lib/pending.js':
        # 
        # - SocketQueue.prototype._dequeue   (sending)
        # - SocketQueue.prototype._onmessage (receiving)
        # 
        # When you create a 'new Request' and send it, it will first create a 'new Packet' and copy
        # some of the values from the request into it, and then call 'send' on that.
        # Similarly, in receiving a reply from a Request instance, handle the 'message' event, which
        # will create a new Packet (the subclass, with the _socket field) from the received data.
        # 
        # See also:
        # - native-dns/lib/client.js
        # - native-dns/lib/pending.js
        # 
        # Ideally we want to be able to reuse the 'req' received here and pass it along
        # to oldDNSLookup without having to recreate or copy any information.
        # See: https://github.com/tjfontaine/node-dns/issues/69
        # 
        # Even more ideally we want to be able to simply pass along the raw data without having to parse it.
        # See: https://github.com/okTurtles/dnschain/issues/6
        # 
        callback: (req, res) ->
            # answering multiple questions in a query appears to be problematic,
            # and few servers do it, so we only answer the first question:
            # https://stackoverflow.com/questions/4082081/requesting-a-and-aaaa-records-in-single-dns-query
            q = req.question[0]
            
            ttl = Math.floor(Math.random() * 3600) + 30 # TODO: pick an appropriate TTL value!
            @log.debug "received question", q

            # TODO: make sure we correctly handle AAAA
            # if q.type != NAME_QTYPE.A
            #     @log.debug "only support 'A' types ATM, deferring request!", {q:q}
            #     @oldDNSLookup(q, res)

            if S(q.name).endsWith '.bit'
                nmcDomain = @namecoinizeDomain q.name
                @log.debug {fn: 'cb|.bit', nmcDomain:nmcDomain, q:q}

                @dnschain.nmc.resolve nmcDomain, (err, result) =>
                    @log.debug {fn: 'nmc_show|cb'}
                    if err
                        @log.error {fn:'nmc_show', err:err, result:result, q:q}
                        @sendErr res
                    else
                        @log.debug {fn:'nmc_show', q:q, result:result}

                        try
                            info = JSON.parse result.value
                        catch e
                            @log.error "bad JSON!", {err:e, result:result, q:q}
                            return @sendErr res, NAME_RCODE.FORMERR

                        # TODO: handle all the types specified in the specification!
                        #       https://github.com/namecoin/wiki/blob/master/Domain-Name-Specification-2.0.md
                        # TODO: handle other info outside of the specification!
                        #       - GNS support
                        #       - DNSSEC/DANE support?

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

                            # ResolverStream will clone 'resolvOpts' in the constructor
                            nsCNAME2IP = new ResolverStream(resolvOpts = log:@log)

                            nsIPs = es.merge(sa(nsIPs), sa(nsCNAMEs).pipe(nsCNAME2IP))

                            # safe to do becase ResolverStream clones the opts
                            resolvOpts.stackedDelay = 1000
                            resolvOpts.reqMaker = (nsIP) =>
                                req = dns2.Request
                                    question: q
                                    server: {address: nsIP}

                            stackedQuery = new ResolverStream resolvOpts
                            stackedQuery.errors = 0

                            nsIPs.on 'data', (nsIP) ->
                                stackedQuery.write nsIP

                            stackedQuery.on 'error', (err) =>
                                if ++stackedQuery.errors == info.ns.length
                                    @log.warn "errors on all NS!", {fn:'nmc_show', q:q, err:err}
                                    @sendErr(res)

                            stackedQuery.on 'answers', (answers) =>
                                nsCNAME2IP.cancelRequests(true)
                                stackedQuery.cancelRequests(true)
                                res.answer.push answers...
                                @log.debug "sending answers!", {fn:'nmc_show', answers:answers, q:q}
                                res.send()

                        else if info.ip
                            # we have its IP! send reply to client
                            # TODO: pick an appropriate 'ttl' for the response!
                            # TODO: handle more info! send the rest of the
                            #       stuff in 'info', and all the IPs!
                            info.ip = [info.ip] if typeof info.ip is 'string'
                            # info.ip.forEach (a)-> res.answer.push ip2type(q.name, ttl)(a)
                            res.answer.push (info.ip.map ip2type(q.name, ttl))...
                            @log.debug {fn:'nmc_show|ip', q:q, answer:res.answer}
                            res.send()
                        else
                            @log.warn {fn: 'nmc_show|404', q:q}
                            @sendErr res, NAME_RCODE.NOTFOUND
            
            else if S(q.name).endsWith '.dns'
                # TODO: right now we're doing a catch-all and pretending they asked
                #       for namecoin.dns...
                res.answer.push ip2type(q.name,ttl,QTYPE_NAME[q.type])(config.get 'dns:externalIP')
                @log.debug {fn:'cb|.dns', q:q, answer:res.answer}
                res.send()
            else
                @log.debug "deferring request", {fn: "cb|else", q:q}
                @oldDNSLookup req, res
        # / end callback

        namecoinizeDomain: (domain) ->
            nmcDomain = S(domain).chompRight('.bit').s
            if (dotIdx = nmcDomain.lastIndexOf('.')) != -1
                nmcDomain = nmcDomain.slice(dotIdx+1) # rm subdomain
            'd/' + nmcDomain # add 'd/' namespace

        oldDNSLookup: (req, res) ->
            method = config.get 'dns:oldDNSMethod'
            sig = "oldDNS{#{method}}"
            q = req.question[0]

            @log.debug {fn:sig+':start', q:q}

            if method is consts.oldDNS.NATIVE_DNS
                success = false
                # TODO: retry in TCP-mode on truncated response (like `dig`)
                #       See: https://github.com/tjfontaine/node-dns/issues/70
                req2 = new dns2.Request
                    question: q
                    server  : config.get 'dns:oldDNS'
                    try_edns: q.type is NAME_QTYPE.ANY or req.edns?

                # 'answer' is a Packet subclass with the .address and ._socket fields
                req2.on 'message', (err, answer) =>
                    if err?
                        @log.error "should not have an error here!", {fn:sig+':error', err:err, answer:answer}
                        req2.DNSErr ?= err
                    else
                        @log.debug {fn:sig+':message', answer:answer}
                        success = true
                        res.header.ra = answer.header.ra
                        _.assign res, _.pick answer, [
                            'edns_version', 'edns_options', 'edns',
                            'answer', 'authority', 'additional'
                        ]

                req2.on 'error', (err='unknown error') =>
                    @log.error {fn:sig+':error', err:err}
                    req2.DNSErr = err

                req2.on 'timeout', (err='timeout') =>
                    @log.warn {fn:sig+':timeout', err:err}
                    req2.DNSErr = err

                req2.on 'end', =>
                    if success
                        @log.debug {fn:sig+':success', q:q, res: _.omit(res, '_socket')}
                        res.send()
                    else
                        # TODO: this is noisy.
                        #       also make log output look good in journalctl
                        @log.warn {fn:sig+':fail', q:q, err:req2.DNSErr, response:_.omit(res, '_socket')}
                        @sendErr res
                # @log.debug {fn:"beforesend", req:req2}
                req2.send()
            else
                dns.resolve q.name, QTYPE_NAME[q.type], (err, addrs) =>
                    if err
                        @log.debug {fn:sig+':fail', q:q, err:err}
                        @sendErr res
                    else
                        # USING THIS METHOD IS DISCOURAGED BECAUSE IT DOESN'T
                        # PROVIDE US WITH CORRECT TTL VALUES!!
                        # TODO: pick an appropriate TTL value!
                        ttl = Math.floor(Math.random() * 3600) + 30
                        res.answer.push (addrs.map ip2type(q.name, ttl, QTYPE_NAME[q.type]))...
                        @log.debug {fn:sig+':success', answer:res.answer, q:q.name}
                        res.send()


        sendErr: (res, code=NAME_RCODE.SERVFAIL) ->
            res.header.rcode = code
            @log.debug {fn:'sendErr', code:code, name:RCODE_NAME[code]}
            res.send()
