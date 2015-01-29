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
            @log = gNewLogger 'Redis'
            @log.info "Loading Redis Cache..."
            if gConf.get('redis:blockchain:enabled') or gConf.get('redis:oldDNS:enabled')
                @log.info "cache enabled"
                [host,port] = gConf.get('redis:socket').split(':')
                @cache =
                    if port?
                        if isNaN(portNum = parseInt port)
                            gErr "Redis port is NaN: #{port}"
                        redis.createClient portNum, host
                    else
                        redis.createClient host
                @blockchainEnabled = gConf.get 'redis:blockchain:enabled'
                @oldDNSEnabled = gConf.get 'redis:oldDNS:enabled'
                @oldDNSTTL = gConf.get 'redis:oldDNS:ttl'
                @cache.on 'error', (err) =>
                    @log.error "cache errored"
                    @shutdown()

            else
                @log.info "cache disabled"

        get: (key, valueRetriever, valueDoer) ->
            @cache.get key, (err, result) =>
                if err
                    @log.error gLineInfo('caching error'), {err: err}
                if result?
                    @log.debug gLineInfo('resolved from cache'), {key: key}
                    valueDoer null, key, JSON.parse result
                    return
                valueRetriever key, (err2, ttl, value) =>
                    @cache.setex(key, ttl, JSON.stringify value) if not err2
                    valueDoer err, key, value

        resolveBlockchain: (resolver, path, options, cb) ->
            if @blockchainEnabled? and resolver.cacheTTL?
                retriever = (key, callback) =>
                    f = (err, result) =>
                        callback err, resolver.cacheTTL, result
                    resolver.resolve path, options, f
                doer = (err, key, result) =>
                    cb err, result
                @get "#{resolver.name}:#{path}:#{JSON.stringify(options)}", retriever, doer
            else
                resolver.resolve path, options, cb

        resolveOldDNS: (req, cb) ->
            if @oldDNSEnabled?
                q = req.question[0]
                ttl =
                    if result2.answer[0]?.ttl?
                        Math.min result2.answer[0]?.ttl, @oldDNSTTL
                    else
                        @oldDNSTTL
                retriever = (key, callback) =>
                    f = (err, result) =>
                        callback err, ttl, result
                    @dnschain.dns.oldDNSLookup req, f
                doer = (err, key, result) =>
                    cb err, result
                @get "oldDNS:#{q.name}:#{q.type}", retriever, doer
            else
                @dnschain.dns.oldDNSLookup req, cb

        shutdown: (cb) ->
            if @blockchainEnabled? or @oldDNSEnabled?
                @blockchainEnabled = false
                @oldDNSEnabled = false
                @log.debug 'shutting down!'
                @cache.end()
            cb?()