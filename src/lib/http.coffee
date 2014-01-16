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

    class HTTPServer
        constructor: (@dnsnmc) ->
            @log = @dnsnmc.log.child server: "dnsnmc#{@dnsnmc.count}-HTTP"

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            for k in ["httpOpts", "nmc"]
                @[k] = @dnsnmc[k]

            @server = http.createServer(@callback) or tErr "http create"
            @server.listen(@httpOpts.port @httpOpts.host) or tErr "http listen"
            @log.info 'started HTTP:', @httpOpts

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        callback: (req, res) ->
            path = url.parse(req.url).pathname.substr(1)
            @log.debug "httpServer server got req for #{path}: #{util.inspect(req)}"

            @nmc.name_show path, (err,result)->
                if err
                    res.writeHead 404,  'Content-Type': 'text/plain'
                    res.write "Not Found: #{path}"
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log 'name_show ' + path + ': ' + util.inspect(result)
                    res.write result.value
                res.end()
