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

###
            __________________________        ________________________
443 traffic |                        |   *--->|      TLSServer       |     ______________
----------->|     EncryptedServer    |--*     | (Dumb decrypter)     |---->| HTTPServer |----> Multiple destinations
            |(Categorization/Routing)|   *    | (One of many)        |     ______________
            __________________________    *   | (Unique destination) |
                                           *  _______________________|
                                            *    _____________   Soon
                                             *-->| TLSServer |----------> Unblock (Vastly simplified)
                                                 _____________
###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    libHTTPS = new ((require "./httpsUtils")(dnschain))
    httpSettings = gConf.get "http"
    unblockSettings = gConf.get "unblock"

    tlsLog = gNewLogger "TLSServer"

    # We fetch the fingerprint directly using OpenSSL and then make sure we got the right thing.
    fingerPrint = ""
    require("child_process").exec "openssl x509 -fingerprint -sha256 -text -noout -in #{httpSettings.tlsCert} | grep SHA256", (err, stdout, stderr) ->
        if err? then throw err
        if stderr.length > 0 then throw new Error stderr
        fingerPrint = stdout.trim()[-95..]
        if not /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test fingerPrint then throw new Error "Could not validate the certificate fingerprint (#{fingerPrint})"
        tlsLog.info "Your certificate fingerprint is #{fingerPrint}"
    setTimeout (() -> if fingerPrint.length == 0 then throw new Error "Took too long to fetch fingerprint"), 1000

    tlsOptions = try
        {
            key: fs.readFileSync httpSettings.tlsKey
            cert: fs.readFileSync httpSettings.tlsCert
        }
    catch err
        tlsLog.error "Cannot read the key/cert pair. See the README for instructions on how to generate them.".bold.red
        tlsLog.error err.message.bold.red
        process.exit -1
    TLSServer = tls.createServer tlsOptions, (c) ->
        libHTTPS.getStream "127.0.0.1", httpSettings.port, (err, stream) ->
            if err?
                tlsLog.error gLineInfo "Tunnel failed: Could not connect to HTTP Server"
                c?.destroy()
                return stream?.destroy()
            c.pipe(stream).pipe(c)
    TLSServer.on "error", (err) -> tlsLog.error err
    TLSServer.listen httpSettings.internalTLSPort, "127.0.0.1", -> tlsLog.info "Listening"

    class EncryptedServer
        constructor: (@dnschain) ->
            @log = gNewLogger "HTTPS"
            @log.debug gLineInfo "Loading HTTPS..."

            @server = net.createServer (c) =>
                libHTTPS.getClientHello c, (err, category, host, buf) =>
                    @log.debug err, category, host, buf?.length
                    if err?
                        @log.debug gLineInfo "TCP handling: "+err.message
                        return c?.destroy()

                    # UNBLOCK: Check if needs to be hijacked

                    isRouted = false # unblockSettings.enabled and unblockSettings.routeDomains[host]?
                    isDNSChain = (
                        (category == libHTTPS.categories.NO_SNI) or
                        ((not unblockSettings.enabled) and category == libHTTPS.categories.SNI) or
                        (unblockSettings.enabled and (host in unblockSettings.acceptApiCallsTo)) or
                        ((host?.split(".")[-1..][0]) == "dns")
                    )
                    isUnblock = false

                    [destination, port, error] = if isRouted
                        ["127.0.0.1", unblockSettings.routeDomains[host], false]
                    else if isDNSChain
                        ["127.0.0.1", httpSettings.internalTLSPort, false]
                    else if isUnblock
                        [host, 443, false]
                    else
                        ["", -1, true]

                    if error
                        @log.error "Illegal domain (#{host})"
                        return c?.destroy()

                    libHTTPS.getStream destination, port, (err, stream) =>
                        if err?
                            @log.error gLineInfo "Tunnel failed: Could not connect to internal TLS Server"
                            c?.destroy()
                            return stream?.destroy()
                        stream.write buf
                        c.pipe(stream).pipe(c)
                        c.resume()
                        @log.debug gLineInfo "Tunnel: "+host

            @server.on "error", (err) -> gErr err
            @server.on "close", -> gErr "HTTPS server was closed unexpectedly."
            @server.listen httpSettings.tlsPort, httpSettings.host, =>
                @log.info gLineInfo("started HTTPS server "), httpSettings

        getFingerPrint: ->
                if fingerPrint.length == 0 then throw new Error "Cached fingerprint couldn't be read, this should not be possible."
                fingerPrint

        shutdown: ->
            @log.debug gLineInfo "HTTPS servers shutting down!"
            @server.close()
