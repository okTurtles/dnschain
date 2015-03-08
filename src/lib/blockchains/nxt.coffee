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

    BlockchainResolver = require('../blockchain.coffee')(dnschain)
    ResolverStream  = require('../resolver-stream')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME
    BLOCKS2SEC = 60

    # Specifications listed here:
    # - https://wiki.namecoin.info/index.php?title=Welcome
    # - https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Importing_and_delegation
    # - https://wiki.namecoin.info/index.php?title=Category:NEP
    # - https://wiki.namecoin.info/index.php?title=Namecoin_Specification
    # TODO: NXT isn't currently following the d/ spec, so we don't use this
    # VALID_NXT_DOMAINS = /^[a-zA-Z0-9]+\/.+/

    class NxtResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NXT'
            @name = 'nxt'
            @tld = 'nxt'
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

                req = http.get @peer + encodeURIComponent(property), (res) ->
                    data = ''
                    res.on 'data', (chunk) ->
                        data += chunk.toString()
                    res.on 'end', () ->
                        try
                            response = JSON.parse data
                            result.data.value = JSON.parse response.aliasURI
                            cb null, result
                        catch e
                            cb e
                req.on 'error', (e) ->
                    cb e

        # just return true for everything for now
        # validRequest: (path) -> VALID_NXT_DOMAINS.test path

        dnsHandler: require('./namecoin')(dnschain).prototype.dnsHandler
