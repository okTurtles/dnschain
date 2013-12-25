###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

'use strict'

exports.dnsnmc = ->
    log = require('bunyan').createLogger
        name:'dnsnmc'
        streams: [{stream: process.stderr, level: 'debug'}]

    [rpc, _, S] = require lib for lib in ['json-rpc2', 'lodash', 'string']
    for dep in ['dns', 'dnsd', 'http', 'url', 'util']
        eval "var #{dep} = require('#{dep}');"

    cfg =
        settings:
            dnsd:
                port: 53
                lhost: '0.0.0.0'
            http:
                port: 80

    tErr = (args...)-> throw new Error args...

    dnsdFn = (req, res) ->
        @log = log.child server: 'dnsd'
        @log.debug req
        var question = res.question[0]
        , hostname = question.name
        , length = hostname.length
        , ttl = Math.floor Math.random() * 3600

        if question.type != 'A'
            @log.debug "not resolving type: " + question.type
            res.end()
         else
            if $(hostname).endsWith '.bit'
                var dot = hostname.indexOf('.'), dotbit = hostname.indexOf('.bit'), dbit = hostname.slice(0)
                if dot != dotbit
                    dbit = dbit.substring(dot+1, dbit.length) # lop off subdomain
                dbit = 'd/' + dbit.substring(0, dbit.length - 4)
                @log.debug "name_show " + dbit
                cfg.clients.rpc.call 'name_show', [dbit], (err, result) ->
                    if not err
                        @log.debug "name_show #{dbit}: %s", result
                        var info = JSON.parse result.value
                        @log.debug "name_show #{dbit} (info): %s", info
                        if info.ns 
                            ns = info.ns[0]
                            dns.resolve4 ns, (err, addrs) ->
                                if err
                                    @log.debug "err["+dbit+'] ' + err
                                    res.end()
                                 else
                                    @log.debug "lookup["+dbit+'] with' + addrs[0]
                                    var req = ndns.Request(
                                        question: ndns.Question({name: hostname, type: 'A'}),
                                        server: {address: addrs[0]}
                                    ).on('message', (err, answer) ->
                                        if (err)
                                            @log.debug "err["+dbit+']/message: ' + err
                                        else {
                                            @log.debug "got answer for "+dbit+': ' + util.inspect(answer)
                                            res.answer.push({name:hostname, type:'A', data:answer.answer[0].address, 'ttl':ttl})
                                        }
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
                
            
        

    httpFn = (req, res) ->
        @log = log.child server: 'dnsd'
        path = url.parse(req.url).pathname.substr(1)
        @log.debug "http server got req for #{path}: #{util.inspect(req)}"

        cfg.clients.rpc.call 'name_show', [path], (err, result)->
            if err
                res.writeHead 404,  'Content-Type': 'text/plain'
                res.write "Not Found: #{path}"
             else
                res.writeHead 200, 'Content-Type': 'application/json'
                @log 'name_show ' + path + ': ' + util.inspect(result)
                res.write result.value
            res.end()


    start: (rpcOpts, dnsOpts={}, httpOpts={}) ->
        try
            {port, lhost, user, pass} = rpcOpts
            cfg.clients.rpc = rpc.Client.create(port, lhost, user, pass) or tErr "rpc create"
            cfg.servers.dnsd = dnsd.createServer(dnsdFn) or tErr "dnsd create"
            cfg.servers.http = http.createServer(httpFn) or tErr "http create"

            # update cfg.settings with the params given
            for pair in [[cfg.settings.dnsd, dnsOpts], [cfg.settings.http, httpOpts]]
                _.merge pair[0], _.pick(pair[1], _.keys(pair[0]))
            # listen all servers
            for k,server of cfg.servers
                server.listen.apply server, cfg.settings[k]
                log.info "#{k} listening on port #{cfg.settings[k].port}"
        catch e
            # TODO: shutdown anything that was launched
            log.error "dnsnmc failed to start: %s", e
            throw e
        


