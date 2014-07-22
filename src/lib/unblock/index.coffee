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
    libTunnel = require("./tunnel")(dnschain)

    class UnblockServer
        constructor: (@dnschain) ->
            @log = gNewLogger "Unblock"
            @log.debug gLineInfo "Loading Unblock..."

            unblockSettings = gConf.get "unblock"
            httpsSettings = gConf.get "https"

            @sourceProtocols = {} # TODO : This will be refactored in issue #34

            ##### HTTPS TUNNELING #####
            @HTTPSserver = net.createServer (c) =>
                libHTTPS.getClientHello c, (err, host, received) =>
                    if err?
                        @log.error gLineInfo "HTTPS tunnel failed: "+err.message
                        return c?.destroy()

                    if not libUtils.isHijacked(host)? then return @log.error "Illegal domain (#{host})"
                    libHTTPS.getStream host, 443, (err, stream) =>
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
            @HTTPSserver.listen httpsSettings.port, httpsSettings.host, =>
                @log.info gLineInfo("started Unblock HTTPS server "), httpsSettings


            ##### HOST TUNNELING #####
            @hostTunnelingServer = tls.createServer {
                key:unblockSettings.hostTunneling.getKey()
                cert:unblockSettings.hostTunneling.getCert()
            }, (c) =>
                libHTTPS.getBrowserExtensionFlag c, (err, isHTTPS, received) =>
                    if err?
                        @log.error gLineInfo "Host Tunneling failed: "+err.message
                        return c?.destroy()

                    if not @sourceProtocols[c.remoteAddress]? then @sourceProtocols[c.remoteAddress] = []
                    @sourceProtocols[c.remoteAddress].push isHTTPS

                    libHTTPS.getStream unblockSettings.host, 44666, (err, stream) =>
                        if err?
                            @log.error gLineInfo "Can't connect to "+unblockSettings.hostTunneling.internalHost+" "+unblockSettings.hostTunneling.internalPort
                            stream?.destroy()
                            return c?.destroy()
                        else
                            stream.write received
                            c.pipe(stream).pipe(c)
                            c.resume()
                            @log.debug gLineInfo "Internal tunnel started"


            @hostTunnelingServer.on "error", (err) -> gErr err
            @hostTunnelingServer.on "close", -> gErr "Unblock Host Tunneling server was closed unexpectedly."
            @hostTunnelingServer.listen unblockSettings.hostTunneling.port, unblockSettings.hostTunneling.host, =>
                @log.info gLineInfo("started Unblock Host Tunneling server "), unblockSettings.hostTunneling

            ##### HOST TUNNELING INTERNAL #####
            @internal = http.createServer (req, res) =>
                @log.debug gLineInfo "Internal Host Tunneling NEW CONNECTION"
                @log.debug gLineInfo(), req.headers
                # TODO : Uncomment once extension works
                # if (not libUtils.isHijacked(req.headers.host)?)
                #     res.writeHead 500
                #     return res.end()

                # if @sourceProtocols[req.connection.remoteAddress].shift()
                #     libTunnel.tunnelHTTPS req, res
                # else
                #     libTunnel.tunnelHTTP req, res

                res.end JSON.stringify req.headers

            @internal.on "error", (err) -> gErr err
            @internal.on "close", -> gErr "Unblock Internal Host Tunneling server was closed unexpectedly."
            @internal.listen unblockSettings.hostTunneling.internalPort, unblockSettings.hostTunneling.internalHost, =>
                @log.info gLineInfo("started Unblock Internal Host Tunneling server "), unblockSettings.hostTunneling

        shutdown: ->
            @log.debug gLineInfo "Unblock servers shutting down!"
            @HTTPSserver.close()
            @hostTunnelingServer.close()
            @internal.close()
