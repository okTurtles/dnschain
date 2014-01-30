###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k};"

    class NMCPeer
        constructor: (@dnsnmc) ->
            # @log = @dnsnmc.log.child server: "NMC"
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
