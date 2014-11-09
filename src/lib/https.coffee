###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    libHTTPS = require "./unblock/https"
    libUtils = require("./unblock/utils")(dnschain)

    class HTTPSServer
        constructor: (@dnschain) ->
            @log = gNewLogger "HTTPS"
            @log.debug gLineInfo "Loading HTTPS..."

            unblockSettings = gConf.get "unblock"
            httpsSettings = gConf.get "https"

            @sourceProtocols = {} # TODO : This will be refactored in issue #34

            ##### Handle the HTTPS Stream depending on magicByte #####
            @HTTPSserver = net.createServer (c) =>
                libHTTPS.getClientHello c, (err, host, buf) =>
                    if err?
                        # No valid SNI found
                        @log.error gLineInfo "HTTPS handling: "+err.message
                        return c?.destroy()

                    if not libUtils.isHijacked(host)?
                        @log.error "Illegal domain (#{host})"
                        return c?.destroy()

                    libHTTPS.getStream host, 443, (err, stream) =>
                    if err?
                        @log.error gLineInfo "HTTPS tunnel failed: Could not connect to "+host
                        c?.destroy()
                        return stream?.destroy()
                    stream.write buf
                    c.pipe(stream).pipe(c)
                    c.resume()
                    @log.debug gLineInfo "HTTPS tunnel: "+host

            @HTTPSserver.on "error", (err) -> gErr err
            @HTTPSserver.on "close", -> gErr "HTTPS server was closed unexpectedly."
            @HTTPSserver.listen httpsSettings.port, httpsSettings.host, =>

            @log.info gLineInfo("started HTTPS server "), httpsSettings

        shutdown: ->
            @log.debug gLineInfo "HTTPS servers shutting down!"
            @HTTPSserver.close()
            @hostTunnelingServer.close()
            @internal.close()
