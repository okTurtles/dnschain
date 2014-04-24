###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak

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
            @log = newLogger 'NMC'
            @log.debug "Loading NMCPeer..."
            
            # we want them in this exact order:
            params = ["port", "connect", "user", "password"].map (x)->config.nmc.get 'rpc'+x
            @peer = rpc.Client.create(params...) or tErr "rpc create"
            @log.info "connected to namecoind: %s:%d", params[1], params[0]

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug "path: '#{path}'", {fn: 'resolve'}
            @peer.call 'name_show', [path], cb
