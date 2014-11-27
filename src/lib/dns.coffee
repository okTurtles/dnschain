###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# TODO: go through 'TODO's!

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    dnsTypeHandlers = require('./dns-handlers')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class DNSServer
        constructor: (@dnschain) ->
            @log = gNewLogger 'DNS'
            @log.debug "Loading DNSServer..."
            @method = gConf.get 'dns:oldDNSMethod'

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
            else if @method isnt gConsts.oldDNS.NATIVE_DNS
                gErr "No such oldDNSMethod: #{@method}"

            @server = dns2.createServer() or gErr "dns2 create"
            @server.on 'sockegError', (err) -> gErr err
            @server.on 'request', @callback.bind(@)
            @server.serve gConf.get('dns:port'), gConf.get('dns:host')

            @log.info 'started DNS', gConf.get 'dns'

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

            if /\.(bit|p2p|eth)$/.test q.name
                if S(q.name).endsWith '.bit'
                    nmcDomain = @namecoinizeDomain q.name
                    resolver = 'nmc'
                else if S(q.name).endsWith '.p2p'
                    # TODO: bdns-izeDomain
                    nmcDomain = S(q.name).chompRight('.p2p').s
                    resolver = 'bdns'
                else
                    # TODO: eth-izeDomain
                    nmcDomain = S(q.name).chompRight('.eth').s
                    resolver = 'eth'
                
                @log.debug gLineInfo("resolving via #{resolver}..."), {nmcDomain:nmcDomain, q:q}

                @dnschain[resolver].resolve nmcDomain, (err, result) =>
                    # @log.warn gLineInfo('blah!'), {result: result}
                    if err? or !result
                        @log.error gLineInfo("#{resolver} failed to resolve"), {err:err?.message, result:result, q:q}
                        @sendErr res
                    else
                        @log.debug gLineInfo("#{resolver} resolved query"), {q:q, d:nmcDomain, result:result}

                        try
                            # result.value = JSON.parse result.value
                            # TODO: [BDNS] this! also, note that we're converting JSON multiple times
                            #       this is ineffecient and ugly.
                            #       organize all this code in a generic way to support all blockchains.
                            result.value = @dnschain[resolver].toJSONobj result
                        catch e
                            @log.warn e.stack
                            @log.warn gLineInfo("bad JSON!"), {q:q, result:result}
                            return @sendErr res, NAME_RCODE.FORMERR

                        if !(handler = dnsTypeHandlers.namecoin[QTYPE_NAME[q.type]])
                            @log.warn gLineInfo("no such handler!"), {q:q, type: QTYPE_NAME[q.type]}
                            return @sendErr res, NAME_RCODE.NOTIMP

                        handler.call @, req, res, qIdx, result, (errCode) =>
                            try
                                if errCode
                                    @sendErr res, errCode
                                else
                                    @log.debug gLineInfo("sending response!"), {resolver:resolver, res:_.omit(res, '_socket')}
                                    res.send()
                            catch e
                                @log.error e.stack
                                @log.error gLineInfo("exception in handler"), {q:q, result:result}
                                return @sendErr res, NAME_RCODE.SERVFAIL

            else if S(q.name).endsWith '.dns'
                # TODO: right now we're doing a catch-all and pretending they asked
                #       for namecoin.dns...
                res.answer.push gIP2type(q.name,ttl,QTYPE_NAME[q.type])(gConf.get 'dns:externalIP')
                @log.debug gLineInfo('cb|.dns'), {q:q, answer:res.answer}
                res.send()
            else
                @log.debug gLineInfo("deferring request"), {q:q}
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

            if @method is gConsts.oldDNS.NATIVE_DNS
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
                        res.header.ra = answer.header.ra
                        _.assign res, _.pick answer, ['edns_version', 'edns_options',
                            'edns', 'answer', 'authority', 'additional']

                req2.on 'error', (err={message:'unknown error'}) =>
                    @log.error gLineInfo('oldDNS lookup error'), {err:err?.message}
                    req2.DNSErr = err

                req2.on 'timeout', (err={message:'timeout'}) =>
                    @log.warn gLineInfo('oldDNS timeout'), {err:err}
                    req2.DNSErr = err

                req2.on 'end', =>
                    if success
                        @log.debug gLineInfo('success!'), {q:q, res: _.omit(res, '_socket')}
                        res.send()
                    else
                        # TODO: this is noisy.
                        #       also make log output look good in journalctl
                        # you can log IP with: res._socket.remote.address
                        @log.warn gLineInfo('oldDNS lookup failed'), {q:q, err:req2.DNSErr}
                        @sendErr res
                # @log.debug {fn:"beforesend", req:req2}
                req2.send()
            else if @method is gConsts.oldDNS.NODE_DNS
                dns.resolve q.name, QTYPE_NAME[q.type], (err, addrs) =>
                    if err
                        @log.debug {fn:sig+':fail', q:q, err:err?.message}
                        @sendErr res
                    else
                        # USING THIS METHOD IS DISCOURAGED BECAUSE IT DOESN'T
                        # PROVIDE US WITH CORRECT TTL VALUES!!
                        # TODO: pick an appropriate TTL value!
                        ttl = Math.floor(Math.random() * 3600) + 30
                        res.answer.push (addrs.map gIP2type(q.name, ttl, QTYPE_NAME[q.type]))...
                        @log.debug {fn:sig+':success', answer:res.answer, q:q.name}
                        res.send()
            else
                # refuse all such queries
                @sendErr res, NAME_RCODE.REFUSED


        sendErr: (res, code=NAME_RCODE.SERVFAIL) ->
            try
                res.header.rcode = code
                @log.debug gLineInfo(), {code:code, name:RCODE_NAME[code]}
                res.send()
            catch e
                @log.error gLineInfo('exception sending error back!'), e.stack
            false # helps other functions pass back an error value
