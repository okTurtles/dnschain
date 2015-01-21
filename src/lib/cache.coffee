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
            if gConf.get('redis:blockchain:enabled') or gConf.get('redis:oldDNS:enabled')
                @log.info "cache enabled"
                [host,port] = gConf.get('redis:socket').split(':')
                @cache = if port?
                    port = parseInt port
                    redis.createClient(port, host)
                else
                    redis.createClient(host)
                if gConf.get('redis:blockchain:enabled')
                    @blockchainEnabled = true
                if gConf.get('redis:oldDNS:enabled')
                    @oldDNSEnabled = true
                    @oldDNSTTL = 600
                @cache.on 'error', (err) =>
                    @log.error "cache errored"
                    @shutdown()

            else
                @log.info "cache disabled"

        resolveBlockchain: (resolver, path, options, cb) ->
            if @blockchainEnabled? and resolver.cacheTTL?
                @cache.get "#{resolver.name}:#{path}:#{JSON.stringify(options)}", (err, result) =>
                    if err or not result?
                        resolver.resolve path, options, cb
                    else
                        @log.debug gLineInfo('resolved from cache'), {path: path, options: options}
                        cb null, JSON.parse(result)
            else
                resolver.resolve path, options, cb

        setBlockchain: (key, ttl, value) ->
            return if not (@blockchainEnabled and ttl?)
            @cache.setex key, ttl, JSON.stringify(value)

        resolveOldDNS: (req, cb) ->
            if @oldDNSEnabled?
                q = req.question[0]
                @cache.get "oldDNS:#{q.name}:#{q.type}", (err, result) =>
                    if err or not result?
                        @dnschain.dns.oldDNSLookup req, (result2, err2) =>
                            if result2? and not err2
                                ttl = if result2.answer[0]?.ttl
                                    Math.min result2.answer[0]?.ttl, @oldDNSTTL
                                else
                                    @oldDNSTTL
                                @cache.setex "oldDNS:#{q.name}:#{q.type}", ttl, JSON.stringify(result2)
                            cb result2, err2
                    else
                        @log.debug gLineInfo('resolved oldDNS from cache'), {req: req}
                        cb JSON.parse(result)
            else
                @dnschain.dns.oldDNSLookup req, cb

        shutdown: -> if @blockchainEnabled? or @oldDNSEnabled?
            @blockchainEnabled = false
            @oldDNSEnabled = false
            @log.debug 'shutting down!'
            @cache.end()
