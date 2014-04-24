#!/usr/bin/env coffee

die = ->
    console.log "got kill signal!"
    server?.shutdown()
    setImmediate -> process.exit 0

process.on 'SIGTERM', die
process.on 'SIGINT', die
process.on 'disconnect', die

process.env.DNS_EXAMPLE = '1'

console.log "Demo starting..."
server = require('../lib/dnschain').createServer()
