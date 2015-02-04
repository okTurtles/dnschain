#!/usr/bin/env coffee

nconf = require 'nconf'
Bottleneck = require 'bottleneck'

# process.env.DNS_EXAMPLE = '1'

nconf.overrides
    dns:
        port: 5333
    http:
        port: 8088
    rateLimiting:
        dns:
            maxConcurrent: 1
            minTime: 200
            highWater: 2
            strategy: Bottleneck.strategy.BLOCK
            penalty: 7000
        http:
            maxConcurrent: 2
            minTime: 150
            highWater: 10
            strategy: Bottleneck.strategy.OVERFLOW
        https:
            maxConcurrent: 2
            minTime: 150
            highWater: 10
            strategy: Bottleneck.strategy.OVERFLOW

module.exports =
    dnschain: require '../../src/lib/dnschain'
