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
            @log = @dnsnmc.newLogger 'NMC'
            @log.debug "Loading NMCPeer..."

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            _.assign @, _.pick(@dnsnmc, ["rpcOpts"])
            rpcParams = ["port", "host", "user", "pass"].map (x)=>@rpcOpts[x]
            @peer = rpc.Client.create(rpcParams...) or tErr "rpc create"
            @log.info "connected to namecoind: %s:%d", @rpcOpts.host, @rpcOpts.port

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        error: (type, err) ->
            @log.error {type:type, err: err}
            if util.isError(err) then throw err else tErr err

        name_show: (path, cb) ->
            @log.debug "name_show: #{path}"
            @peer.call 'name_show', [path], cb
