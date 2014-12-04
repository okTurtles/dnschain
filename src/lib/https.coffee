###

dnschain
https://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    HTTPServer = require('./http')(dnschain)

    # uses HTTPSServer
    class HTTPSServer extends HTTPServer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "HTTPS"
            @log = gNewLogger 'HTTPS'
            @log.debug "Loading HTTPSServer..."

            try
                options =
                    key: fs.readFileSync gConf.get 'http:tlsKey'
                    cert: fs.readFileSync gConf.get 'http:tlsCert'
                @server = https.createServer(options,@callback.bind(@)) or gErr "https create"
                @server.on 'error', (err) -> gErr err
                @server.on 'sockegError', (err) -> gErr err
                @server.listen gConf.get('http:tlsPort'), gConf.get('http:host') or gErr "https listen"
                # @server.listen gConf.get 'https:port') or gErr "https listen"
                @log.info 'started HTTPS', gConf.get 'http'
            catch error
                @log.error error
