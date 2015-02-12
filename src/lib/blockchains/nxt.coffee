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
    VALID_NXT_DOMAINS = /^[a-zA-Z0-9]+\/.+/

    class NxtResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NXT'
            @name = 'nxt'
            @tld = 'nxt'

        config: ->
            @log.debug "Loading #{@name} resolver"

            params = ["port", "connect"].map (x)-> gConf.get "nxt:#{x}"

            if not _.every params
                @log.info "#{@name} disabled. (host or port not defined)"
                return

            @peer = 'http://' + params[1] + ':' + params[0] + '/nxt?requestType=getAlias&aliasName='

            # TODO: $create doesn't actually connect. you need to open a raw socket
            #       or an http socket and see if that works before declaring it works
            @log.info "Nxt API on: %s:%d", params[1], params[0]
            @

        shutdown: (cb) ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!
            cb?()

        resolve: (path, options, cb) ->
            result = @resultTemplate()

            if S(path).endsWith(".#{@tld}")
                path = S(path).chompRight(".#{@tld}").s
                if (dotIdx = path.lastIndexOf('.')) != -1
                    path = path.slice(dotIdx+1) #rm subdomain

            @log.debug gLineInfo("#{@name} resolve"), {path:path}
            
            req = http.get @peer + encodeURIComponent(path), (res) ->
                data = ''
                res.on 'data', (chunk) ->
                    data += chunk.toString()
                res.on 'end', () ->
                    try
                        response = JSON.parse data
                        result.value = JSON.parse response.aliasURI
                        cb null, result
                    catch e
                        cb e
            req.on 'error', (e) ->
                cb e

        validRequest: (path) -> VALID_NXT_DOMAINS.test path

        dnsHandler: require('./namecoin').prototype.dnsHandler
