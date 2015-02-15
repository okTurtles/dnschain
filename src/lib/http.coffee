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

    class HTTPServer
        constructor: (@dnschain) ->
            @log = gNewLogger 'HTTP'
            @log.debug "Loading HTTPServer..."
            @rateLimiting = gConf.get 'rateLimiting:http'

            @server = http.createServer((req, res) =>
                key = "http-#{req.connection?.remoteAddress}"
                limiter = gThrottle key, => new Bottleneck @rateLimiting.maxConcurrent, @rateLimiting.minTime, @rateLimiting.highWater, @rateLimiting.strategy
                limiter.submit (@callback.bind @), req, res, null
            ) or gErr "http create"
            @server.on 'error', (err) -> gErr err
            gFillWithRunningChecks @

        start: ->
            @startCheck (cb) =>
                @server.listen gConf.get('http:port'), gConf.get('http:host'), =>
                    cb null, gConf.get 'http'

        shutdown: ->
            @shutdownCheck (cb) =>
                @log.debug 'shutting down!'
                @server.close cb

        callback: (req, res, cb) ->
            path = S(url.parse(req.url).pathname).chompLeft('/').s
            options = url.parse(req.url, true).query
            @log.debug gLineInfo('request'), {path:path, options:options, url:req.url}

            notFound = =>
                res.writeHead 404,  'Content-Type': 'text/plain'
                res.write "Not Found: #{path}"
                res.end()
                cb()

            [...,resolverName] =
                if S(header = req.headers.blockchain || req.headers.host).endsWith('.dns')
                    S(header).chompRight('.dns').s.split('.')
                else
                    ['none']

            if not (resolver = @dnschain.chains[resolverName])
                @log.warn gLineInfo('unknown blockchain'), {host: req.headers.host, blockchainHeader: req.headers.blockchain, remoteAddress: req.connection.remoteAddress}
                res.writeHead 400, 'Content-Type': 'text/plain'
                res.write "No Blockchain Found: #{resolverName}"
                res.end()
                cb()
                return

            if not resolver.validRequest path
                @log.debug gLineInfo("invalid request: #{path}")
                return notFound()

            @dnschain.cache.resolveBlockchain resolver, path, options, (err,result) =>
                if err
                    @log.debug gLineInfo('resolver failed'), {err:err.message}
                    return notFound()
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug gLineInfo('cb|resolve'), {path:path, result:result}
                    res.write JSON.stringify result
                    res.end()
                    cb()
