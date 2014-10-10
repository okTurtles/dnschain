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

    class NMCPeer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "NMC"
            @log = gNewLogger 'NMC'
            @log.debug "Loading NMCPeer..."
            
            # we want them in this exact order:
            params = ["port", "connect", "user", "password"].map (x)-> gConf.nmc.get 'rpc'+x
            @peer = rpc.Client.$create(params...) or gErr "rpc create"

            # TODO: $create doesn't actually connect. you need to open a raw socket
            #       or an http socket and see if that works before declaring it works
            @log.info "rpc to namecoind on: %s:%d", params[1], params[0]
            # TODO: if namecoin.conf isn't found, disable like in bdns.coffee

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug gLineInfo('nmc resolve'), {path:path}
            @peer.call 'name_show', [path], cb

        # TODO: make this cleaner. this is kinda ugly.
        toJSONstr: (json) -> json.value
        toJSONobj: (json) -> JSON.parse json.value