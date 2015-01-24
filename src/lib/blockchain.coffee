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

    # BlockchainResolver = require('../blockchain.coffee')(dnschain)
    # ResolverStream  = require('./resolver-stream')(dnschain)

    # QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    # NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    # NAME_RCODE = dns2.consts.NAME_TO_RCODE
    # RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class BlockchainResolver # extends BlockchainResolver
        constructor: (@dnschain) ->
            #@log = gNewLogger 'CHAIN'
            #@tld = 'chn'
            #@name = 'templatechain'
            #@cacheTTL = 600 # in seconds, 0 == no cache, override here

        cacheTTL: gConf.get('redis:blockchain:ttl')

        config: ->
            #@log.debug 'Loading #{@name} resolver'
            #load config

        shutdown: ->
            #@log.debug 'shutting down!'

        # cb takes (error, resultObject)
        resolve: (path, options, cb) ->
            #result = @resultTemplate()
            #@log.debug gLineInfo("#{@name} resolve"), {path:path, options:options}

        resultTemplate: ->
            version: '0.0.1'
            header:
                blockchain: @name
            value: {}

        validRequest: (path) -> true

        dnsHandler: {}
