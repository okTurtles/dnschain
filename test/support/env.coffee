#!/usr/bin/env coffee

nconf = require 'nconf'

# process.env.DNS_EXAMPLE = '1'

nconf.overrides
    dns:
        port: 5333
    http:
        port: 8088

module.exports =
    dnschain: require '../../src/lib/dnschain'
