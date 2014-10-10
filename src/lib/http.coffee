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

    # Specifications listed here:
    # - https://wiki.namecoin.info/index.php?title=Welcome
    # - https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Importing_and_delegation
    # - https://wiki.namecoin.info/index.php?title=Category:NEP
    # - https://wiki.namecoin.info/index.php?title=Namecoin_Specification
    VALID_NMC_DOMAINS = /^[a-zA-Z]+\/.+/

    class HTTPServer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "HTTP"
            @log = gNewLogger 'HTTP'
            @log.debug "Loading HTTPServer..."

            @server = http.createServer(@callback.bind(@)) or gErr "http create"
            @server.on 'error', (err) -> gErr err
            @server.on 'sockegError', (err) -> gErr err
            @server.listen gConf.get('http:port'), gConf.get('http:host') or gErr "http listen"
            # @server.listen gConf.get 'http:port') or gErr "http listen"
            @log.info 'started HTTP', gConf.get 'http'

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        # TODO: send a signed header proving the authenticity of our answer

        callback: (req, res) ->
            path = S(url.parse(req.url).pathname).chompLeft('/').s
            @log.debug gLineInfo('request'), {path:path, url:req.url}

            notFound = =>
                res.writeHead 404,  'Content-Type': 'text/plain'
                res.write "Not Found: #{path}"
                res.end()

            resolver = switch req.headers.host
                when 'namecoin.dns' then 'nmc'
                when 'bitshares.dns' then 'bdns'
                else
                    @log.warn gLineInfo "unknown host type: #{req.headers.host} -- defaulting to namecoin.dns!"
                    'nmc'

            if resolver is 'nmc' and not VALID_NMC_DOMAINS.test path
                @log.debug gLineInfo "ignoring request for: #{path}"
                return notFound()

            @dnschain[resolver].resolve path, (err,result) =>
                if err
                    @log.debug gLineInfo('resolver failed'), {err:err}
                    return notFound()
                else
                    res.writeHead 200, 'Content-Type': 'application/json'
                    @log.debug gLineInfo('cb|resolve'), {path:path, result:result}
                    res.write @dnschain[resolver].toJSONstr result
                    res.end()
