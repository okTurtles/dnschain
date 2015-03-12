###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

request = require 'superagent'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    BlockchainResolver = require('../blockchain.coffee')(dnschain)
    ResolverStream  = require('../resolver-stream')(dnschain)

    getAsync = Promise.promisify request.get

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME
    BLOCKS2SEC = 60

    class NxtResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NXT'
            @name = 'nxt'
            @tld = 'nxt'
            @standardizers.dnsInfo = (data) -> data.aliasURI
            gFillWithRunningChecks @

        config: ->
            @log.debug "Loading #{@name} resolver"

            @params = _.transform ["port", "connect"], (o,v) =>
                o[v] = gConf.get 'nxt:'+v
            , {}

            unless _(@params).values().every()
                missing = _.transform @params, ((o,v,k)->if !v then o.push 'nxt:'+k), []
                @log.info "Disabled. Missing params:", missing
                return

            @peer = "http://#{@params.connect}:#{@params.port}/nxt?requestType=getAlias&aliasName="

            @log.info "Nxt API on:", @params
            @

        resources:
            key: (property, operation, fmt, args, cb) ->
                result = @resultTemplate()

                if S(property).endsWith(".#{@tld}")
                    property = S(property).chompRight(".#{@tld}").s
                    if (dotIdx = property.lastIndexOf('.')) != -1
                        property = property.slice(dotIdx+1) #rm subdomain

                @log.debug gLineInfo("#{@name} resolve"), {property:property}

                getAsync(@peer + encodeURIComponent(property)).then (res) =>
                    try
                        json = JSON.parse res.text
                        if json.aliasURI?
                            try json.aliasURI = JSON.parse json.aliasURI
                        result.data = json
                        @log.debug gLineInfo('resolved OK!'), {result:result}
                        cb null, result
                    catch e
                        @log.warn gLineInfo('server did not respond with valid json!'), {err:e.message, url:res.request.url, response:res.text}
                        cb e
                .catch (e) =>
                    @log.error gLineInfo('error contacting NXT server!'), {err:e.message}
                    cb e
