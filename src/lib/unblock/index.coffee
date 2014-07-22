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

    libHTTPS = require "./https"
    libUtils = require("./utils")(dnschain)

    class UnblockServer
        constructor: (@dnschain) ->
            @log = gNewLogger "Unblock"
            @log.debug gLineInfo "Loading Unblock HTTPS server..."

            unblockSettings = gConf.get "unblock"
            httpsSettings = gConf.get "https"

            @HTTPSserver = net.createServer (c) ->
                libHTTPS.getClientHello c, (err, host, received) ->
                    if err?
                        @log.error gLineInfo "HTTPS tunnel failed: "+err.message
                        return c?.destroy()

                    if not libUtils.isHijacked(host)? then return @log.error "Illegal domain (#{host})"
                    libHTTPS.getStream host, 443, (err, stream) ->
                        if err?
                            @log.error gLineInfo "HTTPS tunnel failed: Could not connect to "+host
                            c?.destroy()
                            return stream?.destroy()
                        stream.write received
                        c.pipe(stream).pipe(c)
                        c.resume()
                        @log.debug gLineInfo "HTTPS tunnel: "+host

            @HTTPSserver.on "error", (err) -> gErr err
            @HTTPSserver.on "close", -> gErr "Unblock HTTPS server was closed unexpectedly."
            @HTTPSserver.listen httpsSettings.port, httpsSettings.host, => @log.info gLineInfo("started Unblock HTTPS server "), httpsSettings

        shutdown: ->
            @log.debug gLineInfo "Unblock servers shutting down!"
            @HTTPSserver.close()
