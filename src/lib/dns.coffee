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

        shutdown: -> @server.close()

        deferQuestion: (q, res)->
            req = dns2.Request {question: q, server: @dnsOpts.fallbackDNS}
            req.on 'message', (err, answer) ->
                for a in answer.answer
                    res.answer.push dns2.A(a)
                res.send()
            req.send()

        callback: (req, res) ->
            @log.debug fn:'callback', req

            for question in req.question
                hostname = question.name
                length = hostname.length
                ttl = Math.floor(Math.random() * 3600)

                if question.type != 'A'
                    @log.debug "deferring resolution of type: " + question.type
                    @deferQuestion(question, res)
                else
                    if S(hostname).endsWith '.bit'
                        [dot, dotbit, dbit] = [hostname.indexOf('.'), hostname.indexOf('.bit'), hostname.slice(0)]
                        if dot != dotbit
                            dbit = dbit.substring(dot+1, dbit.length) # lop off subdomain
                        dbit = 'd/' + dbit.substring(0, dbit.length - 4)
                        @log.debug "name_show " + dbit
                        cfg.clients.rpc.call 'name_show', [dbit], (err, result) ->
                            if not err
                                @log.debug "name_show #{dbit}: %s", result
                                info = JSON.parse result.value
                                @log.debug "name_show #{dbit} (info): %s", info
                                if info.ns 
                                    ns = info.ns[0]
                                    dns.resolve4 ns, (err, addrs) ->
                                        if err
                                            @log.debug "err["+dbit+'] ' + err
                                            res.end()
                                        else
                                            @log.debug "lookup["+dbit+'] with' + addrs[0]
                                            req = ndns.Request(
                                                question: ndns.Question({name: hostname, type: 'A'}),
                                                server: {address: addrs[0]}
                                            ).on('message', (err, answer) ->
                                                if (err)
                                                    @log.debug "err["+dbit+']/message: ' + err
                                                else
                                                    @log.debug "got answer for "+dbit+': ' + util.inspect(answer)
                                                    res.answer.push({name:hostname, type:'A', data:answer.answer[0].address, 'ttl':ttl})
                                                
                                            ).on('end', -> res.end()).send()
                                else if info.ip
                                    @log.debug "lookup["+dbit+'] with ip: ' + info.ip[0]
                                    res.answer.push({name:hostname, type:'A', data:info.ip[0], 'ttl':ttl})
                                    res.end()
                            else
                                @log.debug "getinfo [err]: " + err
                        
                    
                    else if S(hostname).endsWith '.nmc'
                        @log.debug "request for secure.dnsnmc.net! sending our IP: " + OURIP
                        res.answer.push({name:hostname, type:'A', data:OURIP, 'ttl':ttl})
                        res.end()
                    else
                        dns.resolve4 hostname, (err, addrs) ->
                            if !err
                                res.answer.push {name:hostname, type:'A', data:addrs[0], 'ttl':ttl}
                            else
                                @log.debug "resolve4 error: " + err
                            res.end()
