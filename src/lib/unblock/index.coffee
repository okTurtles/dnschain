net = require "net"
http = require "http"
libHTTPS = require "./https"

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class UnblockServer
        constructor: (@dnschain) ->
            # console.log "Unblock server constructed!!!!"
            @log = gNewLogger "Unblock"
            @log.debug "Loading Unblock HTTPS server..."

            unblockSettings = gConf.get "unblock"
            httpsSettings = gConf.get "https"

            @HTTPSserver = net.createServer((c) ->
                console.log "UNBLOCK HTTPS CONNECTION!!"
                c.end()
            )
            @HTTPSserver.on "error", (err) -> gErr err
            @HTTPSserver.on "close", -> gErr new Error "Unblock HTTPS server was closed unexpectedly."
            @HTTPSserver.listen httpsSettings.port, httpsSettings.host, => @log.info "started Unblock HTTPS server ", httpsSettings

        shutdown: ->
            console.log "Unblock servers shutting down!"
            @HTTPSserver.close()
            @HTTPserver.close()

