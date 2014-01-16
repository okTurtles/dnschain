###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

'use strict'

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.protected
        eval "var #{k} = dnsnmc.protected.#{k};"

    class NMCPeer
        constructor: (@dnsnmc) ->
            @log = @dnsnmc.log.child server: "dnsnmc#{@dnsnmc.count}-NMC"

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            for k in ["rpcOpts"]
                @[k] = @dnsnmc[k]

            rpcParams = @rpcOpts[k] for k in ["port", "host", "user", "pass"]
            @peer = rpc.Client.create(rpcParams...) or tErr "rpc create"
            @log.info "connected to namecoind: %s:%d", @rpcOpts.host, @rpcOpts.port

        shutdown: ->
            @log.debug 'shutting down!'
            @peer.end()

        name_show: (path, cb) ->
            @log.debug "name_show: #{path}"
            @peer.call 'name_show', [path], cb
