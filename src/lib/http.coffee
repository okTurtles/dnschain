###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class HTTPServer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "HTTP"
            @log = newLogger 'HTTP'
            @log.debug "Loading HTTPServer..."

            @server = http.createServer(@callback.bind(@)) or tErr "http create"
            @server.on 'error', (err) -> tErr err
            @server.on 'socketError', (err) -> tErr err
            @server.listen config.get('http:port'), config.get('http:host') or tErr "http listen"
            # @server.listen(config.get 'http:port') or tErr "http listen"
            @log.info 'started HTTP', config.get 'http'

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        callback: (req, res) ->
            path = S(url.parse(req.url).pathname).chompLeft('/').s
            @log.debug {fn:'cb', path:path, url:req.url}

            @dnschain.nmc.resolve path, (err,result) =>
                if err
                    res.writeHead 404,  'Content-Type': 'text/plain'
                    res.write "Not Found: #{path}"
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug {fn:'cb|resolve', path:path, result:result}
                    res.write result.value
                res.end()
