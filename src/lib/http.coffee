###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

express = require 'express'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class HTTPServer
        constructor: (@dnschain) ->
            @log = gNewLogger 'HTTP'
            @log.debug "Loading HTTPServer..."
            @rateLimiting = gConf.get 'rateLimiting:http'
            app = express()
            router = express.Router()

            router.route(/\/v1\/(\w+)\/(\w+)(\/([^\/]+)(\/(\w+)(\.(\w+))?)?)?/)
            .get (req, res) =>
                [chain, resource, _, property, _, operation, _, fmt] = req.params
                @log.debug gLineInfo('GET v1 API'),
                    {chain:chain, resource:resource, property:property, operation:operation, fmt:fmt}
                if chain is 'resolver'
                    # TODO do resolver stuff
                    res.end()
                else
                    return @notFound(res,400,'No Blockchain Found',chain,->) if not (resolver=@dnschain.chains[chain])
                    return @notFound(res,400,'No Resource Found',resource,->) if not (resolveResource=resolver.resources[resource])
                    resolveResource.call resolver, property, operation, fmt, req.query, @postResolveCallback(res, property,->)

            # support old api
            router.get '/*', @callback.bind(@)

            app.use(router)
            @server = http.createServer((req, res) =>
                key = "http-#{req.connection?.remoteAddress}"
                limiter = gThrottle key, => new Bottleneck @rateLimiting.maxConcurrent, @rateLimiting.minTime, @rateLimiting.highWater, @rateLimiting.strategy
                limiter.submit (app), req, res, null
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
            path = S(url.parse(req.originalUrl).pathname).chompLeft('/').s
            options = url.parse(req.originalUrl, true).query
            @log.debug gLineInfo('request'), {path:path, options:options, url:req.originalUrl}

            [...,resolverName] =
                if S(header = req.headers.blockchain || req.headers.host).endsWith('.dns')
                    S(header).chompRight('.dns').s.split('.')
                else
                    ['none']

            if not (resolver = @dnschain.chains[resolverName])
                @log.warn gLineInfo('unknown blockchain'), {host: req.headers.host, blockchainHeader: req.headers.blockchain, remoteAddress: req.connection.remoteAddress}
                return @notFound res, 400, 'No Blockchain Found', resolverName, cb

            if not resolver.validRequest path
                @log.debug gLineInfo("invalid request: #{path}")
                return @notFound(res, 400, 'Not Found', path, cb)

            @dnschain.cache.resolveBlockchain resolver, path, options, @postResolveCallback(res, path, cb)

        notFound: (res, code, comment, item, cb) =>
            res.writeHead code,  'Content-Type': 'text/plain'
            res.write(comment + ": #{item}")
            res.end()
            cb()

        postResolveCallback: (res, item, cb) =>
            return (err,result) =>
                if err
                    @log.debug gLineInfo('resolver failed'), {err:err.message}
                    return @notFound res, 404, 'Not Found', item, cb
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug gLineInfo('cb|resolve'), {path:item, result:result}
                    res.write JSON.stringify result
                    res.end()
                    cb()
