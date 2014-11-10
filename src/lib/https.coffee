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

    libHTTPS = require "./unblock/https"
    unblockSettings = gConf.get "unblock"
    httpsSettings = gConf.get "https"
    libUtils = require("./unblock/utils")(dnschain)
    exported = class HTTPSServer
        constructor: (@dnschain) ->
            @log = gNewLogger "HTTPS"
            @log.debug gLineInfo "Loading HTTPS..."

            @HTTPSserver = net.createServer (c) =>
                @log.info "HTTPS!!!"
                libHTTPS.getClientHello c, (err, host, buf) =>
                    @log.info err, host, buf.length
                    if err?
                        # Connection is neither a TLS stream nor an HTTPS stream containing an SNI
                        @log.error gLineInfo "TCP handling: "+err.message
                        return c?.destroy()

                    isUnblock = not host? or libUtils.isHijacked(host)?
                    isDNSChain = host?.split(".")[-1..][0] == ".bit"

                    if not (isUnblock or isDNSChain)
                        @log.error "Illegal domain (#{host})"
                        return c?.destroy()

                    if not host?
                        # This means we have a TLS stream
                        host = "127.0.0.1"
                        port = httpsSettings.internalTLSPort
                    else
                        # This means we have an HTTPS stream with an SNI
                        port = 443

                    if isDNSChain
                        #Do stuff with it, for now we just close it
                        @log.debug gLineInfo("Handle DNSChain request"), {host}
                        return c?.destroy()

                    libHTTPS.getStream host, port, (err, stream) =>
                        if err?
                            @log.error gLineInfo "Tunnel failed: Could not connect to "+host
                            c?.destroy()
                            return stream?.destroy()
                        stream.write buf
                        c.pipe(stream).pipe(c)
                        c.resume()
                        @log.debug gLineInfo "Tunnel: "+host

            @HTTPSserver.on "error", (err) -> gErr err
            @HTTPSserver.on "close", -> gErr "HTTPS server was closed unexpectedly."
            @HTTPSserver.listen httpsSettings.port, httpsSettings.host, =>

            @log.info gLineInfo("started HTTPS server "), httpsSettings

        shutdown: ->
            @log.debug gLineInfo "HTTPS servers shutting down!"
            @HTTPSserver.close()
            internalTLSServer.close()

    # This is the 'internal' TLS server used to unwrap the TLS layer.
    # It is only accessible from this file.
    options = {
        key: fs.readFileSync httpsSettings.key
        cert: fs.readFileSync httpsSettings.cert
    }
    internalTLSServer = tls.createServer options, (c) ->
        libHTTPS.getClientHello c, (err, host, buf) =>
            console.log "TLS!!"
            if err? or not host?
                console.log gLineInfo "TLS handling: "+(if err? then err.message else "No valid SNI")
                return c?.destroy()

                isUnblock = libUtils.isHijacked(host)?
                isDNSChain = host.split(".")[-1..][0] == ".bit"

                if not (isUnblock or isDNSChain)
                    console.log "Illegal domain (#{host})"
                    return c?.destroy()

                if isDNSChain
                    #Do stuff with it, for now we just close it
                    console.log gLineInfo("Handle DNSChain request"), {host}
                    return c?.destroy()

            libHTTPS.getStream host, port, (err, stream) =>
                if err?
                    console.log gLineInfo "TLS failed: Could not connect to "+host
                    c?.destroy()
                    return stream?.destroy()
                stream.write buf
                c.pipe(stream).pipe(c)
                c.resume()
                console.log gLineInfo "TLS Tunnel: "+host

    internalTLSServer.listen httpsSettings.internalTLSPort, "127.0.0.1", () -> console.log "Listening"

    exported
