###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# TODO: go through 'TODO's!

Packet = require('native-dns-packet')
getdns = require('getdns')

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class DNSServer
        constructor: (@dnschain) ->
            @log = gNewLogger 'DNS'
            @log.debug "Loading DNSServer..."
            @method = gConf.get 'dns:oldDNSMethod'
            @rateLimiting = gConf.get 'rateLimiting:dns'

            # this is just for development testing of NODE_DNS method
            # dns.setServers ['8.8.8.8']

            if @method is gConsts.oldDNS.NODE_DNS
                @log.warn "Using".bold.red, "oldDNSMethod = NODE_DNS".bold, "method is strongly discouraged!".bold.red
                if dns.getServers?
                    blacklist = _.intersection ['127.0.0.1', '::1', 'localhost'], dns.getServers()
                    if blacklist.length > 0
                        gErr "Cannot use NODE_DNS method when system DNS lists %j as a resolver! Would lead to infinite loop!", blacklist
                else
                    gErr "Node's DNS module doesn't have 'getServers'. Please upgrade NodeJS."
            else if @method is gConsts.oldDNS.NO_OLD_DNS
                @log.warn "oldDNSMethod is set to refuse queries for traditional DNS!".bold
            else if @method is gConsts.oldDNS.NO_OLD_DNS_EVER
                @log.warn "oldDNSMethod is set to refuse *ALL* queries for traditional DNS (even if the blockchain wants us to)!".bold.red
            else if @method is gConsts.oldDNS.NATIVE_DNS
                @log.warn "Using".bold.red, "oldDNSMethod = NATIVE_DNS".bold, "method is deprecated!".bold.red
            else if @method isnt gConsts.oldDNS.GETDNS
                gErr "No such oldDNSMethod: #{@method}"

            gFillWithRunningChecks @

        start: ->
            @startCheck (cb) =>
                if @method is gConsts.oldDNS.GETDNS
                    opts =
                        upstreams: [[
                            gConf.get('dns:oldDNS:address'),
                            gConf.get('dns:oldDNS:port')
                        ]]
                    @context = getdns.createContext opts
                @server = dns2.createServer() or gErr "dns2 create"
                @server.on 'socketError', (err) -> gErr err
                @server.on 'request', (req, res) =>
                    domain = req.question[0]?.name
                    if domain
                        domain = domain.split(".")
                        if domain.length > 3
                            # if there are more than 3 parts to the domain, we use the last
                            # letter of the fourth, and the full parts of the last three
                            # This isn't perfect, especially because of:
                            # https://publicsuffix.org/list/effective_tld_names.dat
                            #
                            # See: https://github.com/okTurtles/dnschain/issues/107 !
                            domain = [domain[-4..][0][-1..]].concat(domain[-3..]).join '.'
                        else
                            domain = domain[-3..].join '.'

                        key = "dns-#{req.address.address}-#{domain}"
                        @log.debug gLineInfo("creating bottleneck on: #{key}")
                        limiter = gThrottle key, => new Bottleneck _.at(@rateLimiting, ['maxConcurrent', 'minTime', 'highWater', 'strategy'])...
                        limiter.changePenalty(@rateLimiting.penalty).submit (@callback.bind @), req, res, null
                    else
                        @log.warn gLineInfo('received empty request!'), {req:req}
                # // end on 'request'
                @server.on 'listening', =>
                    @log.info 'started DNS', gConf.get 'dns'
                    cb()
                @server.serve gConf.get('dns:port'), gConf.get('dns:host')

        shutdown: ->
            @shutdownCheck (cb) =>
                if @method is gConsts.oldDNS.GETDNS
                    @context.destroy()
                if @server
                    @server.on 'close', cb
                    @server.close()
                else
                    @log.warn gLineInfo '@server not defined!'
                    cb()

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
        callback: (req, res, cb) ->
            # answering multiple questions in a query appears to be problematic,
            # and few servers do it, so we only answer the first question:
            # https://stackoverflow.com/questions/4082081/requesting-a-and-aaaa-records-in-single-dns-query
            # At some point we may still want to support this though.
            q = req.question[qIdx=0]
            q.name = q.name.toLowerCase()

            ttl = Math.floor(Math.random() * 3600) + 30 # TODO: pick an appropriate TTL value!
            @log.debug "received question", q

            if (datastore = @dnschain.chainsTLDs[q.name.split('.').pop()])
                @log.debug gLineInfo("resolving via #{datastore.name}..."), {domain:q.name, q:q}

                if not datastore.resources.key?
                    @log.error gLineInfo "#{datastore.name} does not implement `key` resource!".bold
                    return @sendErr(res, NAME_RCODE.SERVFAIL, cb)
                args = [datastore.name , "key", q.name, null, null, {}] # args conform to the datastore API
                resourceRequest = (cb) =>
                    datastore.resources.key.call datastore, args[2..]..., cb
                @dnschain.cache.resolveResource datastore, resourceRequest, JSON.stringify(args), (err, result) =>
                    if err? or !result
                        @log.error gLineInfo("#{datastore.name} failed to resolve"), {err:err?.message, result:result, q:q}
                        @sendErr res, null, cb
                    else
                        @log.debug gLineInfo("#{datastore.name} resolved query"), {q:q, d:q.name, result:result}

                        if not (handler = datastore.dnsHandler[QTYPE_NAME[q.type]])
                            @log.warn gLineInfo("no such DNS handler!"), {datastore: datastore.name, q:q, type: QTYPE_NAME[q.type]}
                            return @sendErr res, NAME_RCODE.NOTIMP, cb

                        handler.call datastore, req, res, qIdx, result.data, (errCode) =>
                            try
                                if errCode
                                    @sendErr res, errCode, cb
                                else
                                    @sendRes res, cb
                            catch e
                                @log.error e.stack
                                @log.error gLineInfo("exception in handler"), {q:q, result:result}
                                return @sendErr res, NAME_RCODE.SERVFAIL, cb

            else if S(q.name).endsWith '.dns'
                res.answer.push gIP2type(q.name,ttl,QTYPE_NAME[q.type])(gConf.get 'dns:externalIP')
                @log.debug gLineInfo('cb|.dns'), {q:q, answer:res.answer}
                @sendRes res, cb
            else
                @log.debug gLineInfo("resolving #{q.name} via oldDNS"), {q:q}
                @dnschain.cache.resolveOldDNS req, (code, packet) =>
                    _.assign res, packet
                    if code
                        @sendErr res, code, cb
                    else
                        @sendRes res, cb
        # / end callback

        # required for now to put the getdns response in a format that native-dns-packet wants
        translateGetDNSResult: (res) ->
            res.additional = []
            res.answer = _.map res.answer, (a) ->
                a.address = a.rdata.ipv4_address || a.rdata.ipv6_address
                a
            @log.debug gLineInfo('parsed getdns'), res
            res

        oldDNSLookup: (req, cb) ->
            res = new Packet()
            sig = "oldDNS{#{@method}}"
            q = req.question[0]
            filterRes = (p) ->
                _.pick p, ['edns_version', 'edns_options', 'edns', 'answer', 'authority', 'additional']

            @log.debug {fn:sig+':start', q:q}

            if @method is gConsts.oldDNS.GETDNS
                @log.debug q
                @context.lookup q.name, q.type, (err, result) =>
                    if err?
                        @log.error gLineInfo('getdns callback error'), {err: err, result: result}
                        cb NAME_RCODE.SERVFAIL, result
                    else
                        @log.debug gLineInfo('getdns callback response'), {result: result}
                        cb null, filterRes(@translateGetDNSResult(result.replies_tree[0]))
            else if @method is gConsts.oldDNS.NATIVE_DNS
                success = false
                # TODO: retry in TCP-mode on truncated response (like `dig`)
                #       See: https://github.com/tjfontaine/node-dns/issues/70
                req2 = new dns2.Request
                    question: q
                    server  : gConf.get 'dns:oldDNS'
                    try_edns: q.type is NAME_QTYPE.ANY or req.edns?

                # 'answer' is a Packet subclass with the .address and ._socket fields
                req2.on 'message', (err, answer) =>
                    if err?
                        @log.error gLineInfo("should not have an error here!"), {err:err?.message, answer:answer}
                        req2.DNSErr ?= err
                    else
                        @log.debug gLineInfo('message'), {answer:answer}
                        success = true
                        res = answer

                req2.on 'error', (err={message:'unknown error'}) =>
                    @log.error gLineInfo('oldDNS lookup error'), {err:err?.message}
                    req2.DNSErr = err

                req2.on 'timeout', (err={message:'timeout'}) =>
                    @log.warn gLineInfo('oldDNS timeout'), {err:err}
                    req2.DNSErr = err

                req2.on 'end', =>
                    if success
                        @log.debug gLineInfo('success!'), {q:q, res: _.omit(res, '_socket')}
                        cb null, filterRes(res)
                    else
                        # TODO: this is noisy.
                        #       also make log output look good in journalctl
                        # you can log IP with: res._socket.remote.address
                        @log.warn gLineInfo('oldDNS lookup failed'), {q:q, err:req2.DNSErr}
                        cb NAME_RCODE.SERVFAIL, filterRes(res)
                # @log.debug {fn:"beforesend", req:req2}
                req2.send()
            else if @method is gConsts.oldDNS.NODE_DNS
                dns.resolve q.name, QTYPE_NAME[q.type], (err, addrs) =>
                    if err
                        @log.debug {fn:sig+':fail', q:q, err:err?.message}
                        cb NAME_RCODE.SERVFAIL, filterRes(res)
                    else
                        # USING THIS METHOD IS DISCOURAGED BECAUSE IT DOESN'T
                        # PROVIDE US WITH CORRECT TTL VALUES!!
                        # TODO: pick an appropriate TTL value!
                        ttl = Math.floor(Math.random() * 3600) + 30
                        res.answer.push (addrs.map gIP2type(q.name, ttl, QTYPE_NAME[q.type]))...
                        @log.debug {fn:sig+':success', answer:res.answer, q:q.name}
                        cb null, filterRes(res)
            else
                # refuse all such queries
                cb NAME_RCODE.REFUSED, res

        sendRes: (res, cb) ->
            try
                @log.debug gLineInfo("sending response!"), {res:_.omit(res, '_socket')}
                res.send()
                cb()
            catch e
                @log.error gLineInfo('error trying send response back!'), {msg:e.message, res:_.omit(res, '_socket'), stack:e.stack}
                cb e

        sendErr: (res, code=NAME_RCODE.SERVFAIL, cb) ->
            try
                res.header.rcode = code
                @log.debug gLineInfo(), {code:code, name:RCODE_NAME[code]}
                res.send()
            catch e
                @log.error gLineInfo('exception sending error back!'), e.stack
            cb()
            false # helps other functions pass back an error value
