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

    class BDNSPeer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "BDNS"
            @log = gNewLogger 'BDNS'
            @log.debug "Loading BDNSPeer..."
            
            # we want them in this exact order:
            params = ["port", "connect", "user", "password"].map (x)-> gConf.bdns.get 'rpc'+x
            @peer = rpc.Client.$create(params...) or gErr "rpc create"
            @log.info "connected to namecoind: %s:%d", params[1], params[0]

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug {fn: 'resolve', path: path}
            @peer.call 'wallet_get_account', [path], cb
