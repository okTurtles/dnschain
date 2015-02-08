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

    try
        for f in ['tlsKey', 'tlsCert']
            throw f unless fs.existsSync httpSettings[f]
    catch key
        tlsLog.error (msg = "file for http:#{key} does not exist: #{httpSettings[key]}").bold.red
        tlsLog.error "Vist this link for information on how to generate this file:".bold
        tlsLog.error "https://github.com/okTurtles/dnschain/blob/master/docs/How-do-I-run-my-own.md#getting-started".bold
        throw new Error msg

    tlsLog.info " Key path: #{httpSettings.tlsKey}"
    tlsLog.info "Cert path: #{httpSettings.tlsCert}"

    tlsOptions =
        key: fs.readFileSync httpSettings.tlsKey
        cert: fs.readFileSync httpSettings.tlsCert

    # We fetch the fingerprint directly using OpenSSL and then make sure we got the right thing.
    fingerprint = ""
    fingerprintCmd = "openssl x509 -fingerprint -sha256 -text -noout -in #{httpSettings.tlsCert} | grep SHA256"

    # TODO: convert to `execSync` when more people switch to node 0.12
    require('child_process').exec fingerprintCmd, {timeout:1000}, (err, stdout, stderr) ->
        throw err if err?
        throw new Error stderr if stderr.length > 0
        fingerprint = stdout.replace(/\r/g, "\n").split("\n")[0].trim()[-95..]
        unless /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test fingerprint
            throw new Error "Could not validate the certificate fingerprint (#{fingerprint})"
        
        tlsLog.info "Your certificate fingerprint is:", fingerprint.bold

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
            @rateLimiting = gConf.get 'rateLimiting:https'

            @server = net.createServer (c) =>
                key = "https-#{c.remoteAddress}"
                limiter = gThrottle key, => new Bottleneck @rateLimiting.maxConcurrent, @rateLimiting.minTime, @rateLimiting.highWater, @rateLimiting.strategy
                limiter.submit (@callback.bind @), c, null
            @server.on "error", (err) -> gErr err
            @server.on "close", => @log.info "HTTPS server has shutdown."
            @server.listen httpSettings.tlsPort, httpSettings.host, =>
                @log.info gLineInfo("started HTTPS server "), httpSettings

        callback: (c, cb) ->
            libHTTPS.getClientHello c, (err, category, host, buf) =>
                @log.debug err, category, host, buf?.length
                if err?
                    @log.debug gLineInfo "TCP handling: "+err.message
                    cb()
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
                    cb()
                    return c?.destroy()

                libHTTPS.getStream destination, port, (err, stream) =>
                    if err?
                        @log.error gLineInfo "Tunnel failed: Could not connect to internal TLS Server"
                        c?.destroy()
                        cb()
                        return stream?.destroy()
                    stream.write buf
                    c.pipe(stream).pipe(c)
                    c.resume()
                    cb()
                    @log.debug gLineInfo "Tunnel: "+host

        getFingerprint: ->
            if fingerprint.length == 0
                throw new Error "Cached fingerprint couldn't be read."
            else
                fingerprint

        shutdown: (cb=->) ->
            @log.debug "HTTPS servers shutting down!"
            TLSServer.close() # node docs don't indicate this takes a callback
            @server.close cb
