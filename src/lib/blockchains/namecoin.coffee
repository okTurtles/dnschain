###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

BlockchainResolver = require '../blockchain.coffee'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # Specifications listed here:
    # - https://wiki.namecoin.info/index.php?title=Welcome
    # - https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Importing_and_delegation
    # - https://wiki.namecoin.info/index.php?title=Category:NEP
    # - https://wiki.namecoin.info/index.php?title=Namecoin_Specification
    VALID_NMC_DOMAINS = /^[a-zA-Z]+\/.+/

    class NamecoinResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NMC'
            @name = 'namecoin'
            @tld = 'bit'

        config: ->
            @log.debug "Loading NamecoinResolver..."
            
            # we want them in this exact order:
            params = ["port", "connect", "user", "password"].map (x)-> gConf.nmc.get 'rpc'+x
            @peer = rpc.Client.$create(params...) or gErr "rpc create"

            # TODO: $create doesn't actually connect. you need to open a raw socket
            #       or an http socket and see if that works before declaring it works
            @log.info "rpc to namecoind on: %s:%d", params[1], params[0]
            # TODO: if namecoin.conf isn't found, disable like in bdns.coffee
            @

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, options, cb) ->
            result = @resultTemplate()
            if S(path).endsWith(".#{@tld}") # naimcoinize Domain
                path = S(path).chompRight(".#{@tld}").s
                if (dotIdx = path.lastIndexOf('.')) != -1
                    path = path.slice(dotIdx+1) #rm subdomain
                path = 'd/' + path
            cb 'INVALIDNMC',{} if not VALID_NMC_DOMAINS.test path
            @log.debug gLineInfo("#{@name} resolve"), {path:path}
            @peer.call 'name_show', [path], (err, ans) ->
                return cb(err) if err
                try
                    result.value = JSON.parse ans.value
                    cb null, result
                catch e
                    @log.error gLineInfo(e.message)
                    cb e
