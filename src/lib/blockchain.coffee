###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# BlockchainResolver = require "../blockchain.coffee"

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class BlockchainResolver # extends BlockchainResolver
        constructor: (@dnschain) ->
            #@log = gNewLogger 'CHAIN'
            #@tld = 'chn'
            #@name = 'templatechain'

        config: ->
            #@log.debug "Loading BlockchainResolver..."

        shutdown: ->
            #@log.debug 'shutting down!'

        resolve: (path, options, cb) ->
            #@log.debug gLineInfo('resolve'), {path:path, options:options}

        resultTemplate: ->
            version: '0.0.1'
            header:
                blockchain: @name
            value: {}
