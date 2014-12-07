###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

###
This file contains the logic to handle connections on port 443
These connections can be naked HTTPS or wrapped inside of TLS
###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    libHTTPS = new ((require "./httpsUtils")(dnschain))
    settings = gConf.get "http"
    class HTTPSServer
        constructor: (@dnschain) ->
            @log = gNewLogger "HTTPS"
            @log.debug gLineInfo "Loading HTTPS..."

            @server = net.createServer (c) =>
                libHTTPS.getClientHello c, (err, host, buf) =>
                    @log.info err, host, buf.length
                    if err?
                        # Connection is neither a TLS stream nor an HTTPS stream containing an SNI
                        @log.error gLineInfo "TCP handling: "+err.message
                        return c?.destroy()

                    # UNBLOCK: Check if needs to be hijacked
                    isUnblock = false
                    isDNSChain = (host?.split(".")[-1..][0]) in ["dns", "bit", "p2p"]

                    if not (isUnblock or isDNSChain)
                        @log.error "Illegal domain (#{host})"
                        return c?.destroy()

                    if isDNSChain
                        host = "127.0.0.1"
                        # There'll be more eventually!
                        port = settings.internalAdminPort

                    if not host?
                        # This means we have a TLS stream
                        host = "127.0.0.1"
                        port = -1 #settings.internalTLSPort
                        return c?.destroy() #For now

                    console.log host, port
                    libHTTPS.getStream host, port, (err, stream) =>
                        if err?
                            @log.error gLineInfo "Tunnel failed: Could not connect to "+host
                            c?.destroy()
                            return stream?.destroy()
                        stream.write buf
                        c.pipe(stream).pipe(c)
                        c.resume()
                        @log.debug gLineInfo "Tunnel: "+host

            @server.on "error", (err) -> gErr err
            @server.on "close", -> gErr "HTTPS server was closed unexpectedly."
            @server.listen settings.tlsPort, settings.host, =>

            @log.info gLineInfo("started HTTPS server "), settings

        shutdown: ->
            @log.debug gLineInfo "HTTPS servers shutting down!"
            @server.close()
            internalTLSServer.close()
