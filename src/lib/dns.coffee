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

    BLOCKS2SEC = 10 * 60

    # It is the hander's job to add answers to 'res' but *NOT* to send them!
    # The only sending it can do is by calling @sendErr. If an error occurs
    # (and thus requiring a call to @sendErr), then the return value of
    # @sendErr *MUST* be returned by the handler (should be 'false', but
    # double-check the actual implementation).
    # 
    # IMPORTANT: these functions *MUST* be bound to the
    #            DNSServer instance that calls them!
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
                info = data.value
                q = req.question[qIdx]
                ttl = data.expires_in? * BLOCKS2SEC
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
                            @log.warn "errors on all NS!", {fn:'A', q:q, err:err}
                            cb NAME_RCODE.SERVFAIL

                    stackedQuery.on 'answers', (answers) =>
                        nsCNAME2IP.cancelRequests(true)
                        stackedQuery.cancelRequests(true)
                        res.answer.push answers...
                        cb()

                else if info.ip
                    # we have its IP! send reply to client
                    # TODO: handle more info! send the rest of the
                    #       stuff in 'info', and all the IPs!
                    info.ip = [info.ip] if typeof info.ip is 'string'
                    # info.ip.forEach (a)-> res.answer.push ip2type(q.name, ttl)(a)
                    res.answer.push (info.ip.map ip2type(q.name, ttl))...
                    cb()
                else
                    @log.warn {fn: 'nmc_show|404', q:q}
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
                    res.answer.push tls2tlsa(info.tls, ttl, q.name)...
                # check if any records were added
                if res.answer.length - len is 0
                    @log.warn {fn: 'TLSA|404', q:q, data:data}
                    cb NAME_RCODE.NOTFOUND
                else
                    cb()

            ANY: ->
                # TODO: loop through 'info' and call approrpriate handlers
                #       return immediately if any of them calls @sendErr
                # TODO: enable EDNS reply
                dnsTypeHandlers.namecoin.A.apply @, [].slice.call arguments

    class DNSServer
        constructor: (@dnschain) ->
            @log = newLogger 'DNS'
            @log.debug "Loading DNSServer..."
            @method = config.get 'dns:oldDNSMethod'

            # this is just for development testing of NODE_DNS method
            # dns.setServers ['8.8.8.8']
            
            if @method is consts.oldDNS.NODE_DNS
                @log.warn "Using", "oldDNS.NODE_DNS".bold, "method is strongly discouraged!"
                if dns.getServers?
                    blacklist = _.intersection ['127.0.0.1', '::1', 'localhost'], dns.getServers()
                    if blacklist.length > 0
                        tErr "Cannot use NODE_DNS method when system DNS lists %j as a resolver! Would lead to infinite loop!", blacklist
                else
                    tErr "Node's DNS module doesn't have 'getServers'. Please upgrade NodeJS."

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
            # At some point we may still want to support this though.
            q = req.question[qIdx=0]
            q.name = q.name.toLowerCase()
            
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
                    @log.debug fn: fn = 'nmc_show|cb'

                    if err
                        @log.error {fn:fn, err:err, result:result, q:q}
                        @sendErr res
                    else
                        @log.debug {fn:fn, q:q, result:result}

                        try
                            result.value = JSON.parse result.value
                        catch e
                            @log.error "bad JSON!", {fn: fn, exception:e, q:q, result:result}
                            return @sendErr res, NAME_RCODE.FORMERR

                        try
                            if !(handler = dnsTypeHandlers.namecoin[QTYPE_NAME[q.type]])
                                @log.warn "no such handler!", {q:q, type: QTYPE_NAME[q.type]}
                                return @sendErr res, NAME_RCODE.NOTIMP

                            handler.call @, req, res, qIdx, result, (errCode) =>
                                if errCode
                                    @sendErr res, errCode
                                else
                                    @log.debug "sending response!", {fn:'cb', res:_.omit(res, '_socket')}
                                    res.send()
                        catch e
                            @log.error e.stack
                            @log.error "exception in handler", {fn:fn, q:q, result:result}
                            return @sendErr res, NAME_RCODE.SERVFAIL

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
            sig = "oldDNS{#{@method}}"
            q = req.question[0]

            @log.debug {fn:sig+':start', q:q}

            if @method is consts.oldDNS.NATIVE_DNS
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
            false # helps other functions pass back an error value
