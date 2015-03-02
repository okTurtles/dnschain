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

            # Openname spec defined here:
            # - https://github.com/okTurtles/openname-specifications/blob/resolvers/resolvers.md
            # - https://github.com/openname/openname-specifications/blob/master/resolvers.md

            opennameRoute = express.Router()

            # Resolver specific API
            opennameRoute.get /\/(?:resolver|dnschain)\/([^\/\.]+)(?:\.([a-z]+))?/, (req, res) =>
                @log.debug gLineInfo("resolver API called"), {params: req.params}
                [resource, format] = req.params
                if resource == "fingerprint"
                    if !format or format is 'json'
                        res.json {fingerprint: @dnschain.encryptedserver.getFingerprint()}
                    else
                        @sendErr req, res, 400, "Unsupported format: #{format}"
                else
                    @sendErr req, res, 400, "Bad resource: #{resource}"

            # Datastore API
            # Note: JavaScript doesn't have negative lookbehind support
            #       so we use the negative lookahead hacks mentioned here:
            #       https://stackoverflow.com/questions/977251/regular-expressions-and-negating-a-whole-character-group
            opennameRoute.route(/// ^
                \/(\w+)                             # the datastore name
                \/(\w+)                             # the corresponding resource
                (?:\/((?:(?!\.json|\.xml)[^\/])+))? # optional property (or action on resource)
                (?:\/((?:(?!\.json|\.xml)[^\/])+))? # optional action on property
                (?:\.(json|xml))?                   # optional response format
                $ ///
            ).get (req, res) =>
                @log.debug gLineInfo("get v1"), {params: req.params, queryArgs: req.query}
                @callback  req, res, [_.values(req.params)..., req.query]

            opennameRoute.use (req, res) =>
                @sendErr req, res, 400, "Bad v1 request"

            app.use "/v1", opennameRoute
            app.get "*", (req, res) => # Old, deprecated API usage.
                path = S(url.parse(req.originalUrl).pathname).chompLeft('/').s
                options = url.parse(req.originalUrl, true).query
                @log.debug gLineInfo('deprecated request'), {path:path, options:options, url:req.originalUrl}

                [...,datastoreName] =
                    if S(header = req.headers.blockchain || req.headers.host).endsWith('.dns')
                        S(header).chompRight('.dns').s.split('.')
                    else
                        ['none']

                @callback req, res, [datastoreName, "key", path, null, null, options]

            app.use (err, req, res, next) =>
                @log.warn gLineInfo('error handler triggered'),
                    errMessage: err?.message
                    stack: err?.stack
                    req: _.at(req, ['originalUrl','ip','ips','protocol','hostname','headers'])
                res.status(500).send "Internal Error: #{err?.message}"

            @server = http.createServer (req, res) =>
                key = "http-#{req.connection?.remoteAddress}"
                @log.debug gLineInfo("creating bottleneck on: #{key}")
                limiter = gThrottle key, => new Bottleneck _.at(@rateLimiting, ['maxConcurrent','minTime','highWater','strategy'])...

                # Since Express doesn't take a callback function
                # we capture the callback that Bottleneck requires
                # in `bottleCB` and call it by hooking into `res.end`
                savedEnd = res.end.bind(res)
                bottleCB = null
                res.end = (args...) =>
                    savedEnd args...
                    bottleCB()

                limiter.submit (cb) ->
                    bottleCB = cb
                    app req, res
                , null

            gErr("http create") unless @server

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

        callback: (req, res, args) ->
            [datastoreName, resourceName, propOrAction] = args
            if not (datastore = @dnschain.chains[datastoreName])
                return @sendErr req, res, 400, "Unsupported datastore: #{datastoreName}"
            if not (resourceFn = datastore.resources[resourceName])
                return @sendErr req, res, 400,"Unsupported resource: #{resourceName}"
            # TODO: deal with datastore.validRequest
            resourceRequest = (cb) =>
                resourceFn.call datastore, args[2..]..., cb
            @dnschain.cache.resolveResource resourceRequest, JSON.stringify(args), (err,result) =>
                if err
                    @log.debug gLineInfo('resolver failed'), {err:err.message}
                    @sendErr req, res, 404, "Not Found: #{propOrAction}"
                else
                    @log.debug gLineInfo('postResolve'), {path:propOrAction, result:result}
                    res.json result

        sendErr: (req, res, code=404, comment="Not Found") =>
            @log.warn gLineInfo('notFound'),
                comment: comment
                code: code
                req: _.at(req, ['originalUrl','protocol','hostname'])
            res.status(code).send comment
