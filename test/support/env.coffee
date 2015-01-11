#!/usr/bin/env coffee

nconf = require 'nconf'

die = ->
    console.log "got kill signal!"
    server?.shutdown()
    # setImmediate -> process.exit 0

process.on 'SIGTERM', die
process.on 'SIGINT', die
process.on 'disconnect', die

# process.env.DNS_EXAMPLE = '1'

nconf.overrides
    dns:
        port: 5333
    http:
        port: 8088

console.log "Starting DNSChain for testing..."
server = require('../../src/lib/dnschain').createServer()
