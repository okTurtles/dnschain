###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

'use strict'

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.protected
        eval "var #{k} = dnsnmc.protected.#{k};"

    class DNSServer
        constructor: (@dnsnmc) ->
            @log = @dnsnmc.log.child server: "dnsnmc#{@dnsnmc.count}-DNS"

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            for k in ["dnsOpts", "nmc"]
                @[k] = @dnsnmc[k]

            @server = dns2.createServer() or tErr "dns2 create"
            @server.on 'request', @callback
            @server.serve(@dnsOpts.port @dnsOpts.host) or tErr "dns serve"
            @log.info 'started DNS:', @dnsOpts

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        deferQuestion: (q, res)->
            req = dns2.Request {question: q, server: @dnsOpts.fallbackDNS}
            req.on 'message', (err, answer) ->
                for a in answer.answer
                    res.answer.push dns2.A(a)
                res.send()
            req.send()

        namecoinizeDomain: (domain) ->
            nmcDomain = S(domain).chompRight('.bit').s
            if (dotIdx = domain.indexOf('.')) != -1
                nmcDomain = nmcDomain.slice(dotIdx+1) # rm subdomain
            'd/' + nmcDomain # add 'd/' namespace

        sendErr: (res, code) ->
            res.header.rcode = code
            @log.warn {fn: 'sendErr', response: res}, "sending back error #{code}: #{dns2.RCODE_TO_NAME[code]}"
            res.send()

        callback: (req, res) ->
            @log.debug fn:'callback', req

            for question in req.question
                domain = question.name
                length = domain.length
                ttl = Math.floor(Math.random() * 3600)

                if question.type != 'A'
                    @log.debug deffering: question.type, "deferring resolution"
                    @deferQuestion(question, res) # deferQuestion handles sending response
                else
                    if S(domain).endsWith '.bit'
                        nmcDomain = @namecoinizeDomain domain
                        @nmc.name_show nmcDomain, (err, result) ->
                            if err
                                @log.error err: err, "name_show failed for: #{nmcDomain}: %s", result
                                # TODO: SEND PROPER ERROR RESPONSE BACK TO CLIENT!!
                                @sendErr res, dns2.consts.NAME_TO_RCODE.SERVFAIL
                            else
                                @log.debug result: result, "result for name_show #{nmcDomain}"
                                info = JSON.parse result.value

                                # TODO: handle all the types specified in the specification!
                                #       https://github.com/namecoin/wiki/blob/master/Domain-Name-Specification-2.0.md
                                # TODO: handle other info outside of the specification!
                                #       - GNS support
                                #       - DNSSEC/DANE support?

                                # According to NMC specification, specifying 'ns'
                                # overrules 'ip' value, so check it here and resolve using
                                # old-style DNS.
                                if info.ns?.length > 0
                                    # if the DNS is specified as a domain (instead of IP)
                                    # then we need to look up that server's IP.

                                    # TODO: we need to keep trying other servers until success
                                    #       (or exhaustion)
                                    ns = info.ns.pop()

                                    # TODO: handle ns = IPv6 addr!

                                    if S(ns).replaceAll('.','').isNumeric()
                                        # we have its IP, immediately send query to it
                                    else
                                        # we need to resolve the DNS server and get its IP


                                    dns.resolve4 ns, (err, addrs) ->
                                        if err
                                            @log.debug "err["+nmcDomain+'] ' + err
                                            res.end()
                                        else
                                            @log.debug "lookup["+nmcDomain+'] with' + addrs[0]
                                            req = dns2.Request(
                                                question: dns2.Question({name: domain, type: 'A'}),
                                                server: {address: addrs[0]}
                                            ).on('message', (err, answer) ->
                                                if (err)
                                                    @log.debug "err["+nmcDomain+']/message: ' + err
                                                else
                                                    @log.debug "got answer for "+nmcDomain+': ' + util.inspect(answer)
                                                    res.answer.push({name:domain, type:'A', data:answer.answer[0].address, 'ttl':ttl})
                                                
                                            ).on('end', -> res.end()).send()
                                else if info.ip
                                    # we have its IP! send reply to client
                                    @log.debug "lookup["+nmcDomain+'] with ip: ' + info.ip[0]
                                    # TODO: pick an appropriate 'ttl' for the response!
                                    # TODO: handle more info! send the rest of the
                                    #       stuff in 'info', and all the IPs!
                                    res.answer.push dns2.A {name:domain, data:info.ip[0]}
                                    res.end()
                                # TODO: handle info.ip6!
                    
                    else if S(domain).endsWith '.nmc'
                        @log.debug "request for secure.dnsnmc.net! sending our IP: " + OURIP
                        res.answer.push({name:domain, type:'A', data:OURIP, 'ttl':ttl})
                        res.end()
                    else
                        dns.resolve4 domain, (err, addrs) ->
                            if !err
                                res.answer.push {name:domain, type:'A', data:addrs[0], 'ttl':ttl}
                            else
                                @log.debug "resolve4 error: " + err
                            res.end()
