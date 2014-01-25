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

    class HTTPServer
        constructor: (@dnsnmc) ->
            # @log = @dnsnmc.log.child server: "HTTP"
            @log = @dnsnmc.newLogger 'HTTP'
            @log.debug "Loading HTTPServer..."

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            _.assign @, _.pick(@dnsnmc, ["httpOpts", "nmc"])

            @server = http.createServer(@callback.bind(@)) or tErr "http create"
            @server.on 'error', (err) => @error('error', err)
            @server.on 'socketError', (err) => @error('socketError', err)
            @server.listen(@httpOpts.port, @httpOpts.host) or tErr "http listen"
            @log.info {opts: @httpOpts}, 'started HTTP'

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        error: (type, err) ->
            @log.error {type:type, err: err}
            if util.isError(err) then throw err else tErr err

        callback: (req, res) ->
            path = S(url.parse(req.url).pathname).chompLeft('/').s
            @log.debug {fn:'HTTPcb', path:path, url:req.url}

            @nmc.name_show path, (err,result) =>
                if err
                    res.writeHead 404,  'Content-Type': 'text/plain'
                    res.write "Not Found: #{path}"
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug {fn:'HTTPcb->name_show', path:path, result:result}
                    res.write result.value
                res.end()
