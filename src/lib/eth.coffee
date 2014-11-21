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

    class ETHPeer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "ETH"
            @log = gNewLogger 'ETH'
            @log.debug "Loading ETHPeer..."
            
            # we want them in this exact order:
            params = ["rpcport", "rpcconnect"].map (x)-> gConf.eth.get x
            @peer = rpc.Client.$create(params...).connectSocket(->) or gErr "rpc create"

            @log.info "rpc to ethereum on: %s:%d", params[1], params[0]

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug gLineInfo('eth resolve'), {path:path}
            path_args = path.split '/'
            if path_args.length is 1
                path_args = [{
                    address: ''
                    key: path_args[0]}]
            else
                path_args = [{
                    address: path_args[0]
                    key: path_args[1..].join '/'}]
            @peer.call 'EthereumApi.GetStorageAt', path_args, cb

        # TODO: make this cleaner. this is kinda ugly.
        toJSONstr: (json) -> json
        toJSONobj: (json) -> JSON.parse json
