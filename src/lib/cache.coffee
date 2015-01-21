###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

redis = require 'redis'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class ResolverCache
        constructor: (@dnschain) ->
            @log = gNewLogger 'CACHE'
            @log.info "Loading Redis Cache..."
            if gConf.get('redis:enabled')
                @log.info "cache enabled"
                @cache = redis.createClient(gConf.get('redis:port'), gConf.get('redis:host'))
                @enabled = true
                @cache.on 'error', (err) =>
                    @log.error "cache errored"
                    @shutdown()

            else
                @log.info "cache disabled"

        resolve: (resolver, path, options, cb) ->
            if @enabled? and resolver.cacheTTL?
                @cache.get "#{resolver.name}:#{path}:#{JSON.stringify(options)}", (err, result) =>
                    if err or not result?
                        resolver.resolve path, options, cb
                    else
                        @log.debug gLineInfo('resolved from cache'), {path: path, options: options}
                        cb null, JSON.parse(result)
            else
                resolver.resolve path, options, cb

        set: (key, ttl, value) ->
            return if not (@enabled and ttl?)
            @cache.setex key, ttl, JSON.stringify(value)

        shutdown: -> if @enabled
            @enabled = false
            @log.debug 'shutting down!'
            @cache.end()
