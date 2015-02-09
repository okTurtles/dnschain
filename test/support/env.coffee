#!/usr/bin/env coffee

nconf = require 'nconf'
Bottleneck = require 'bottleneck'
rpc = require 'json-rpc2'

process.env.TEST_DNSCHAIN = 1

# We can test Redis with a real redis instance or with 'fakeredis':
# https://github.com/hdachev/fakeredis
# 
# By default we use fakeredis.
# Set the TEST_REAL_REDIS environment variable to test with real server.

nconf.overrides
    dns:
        port: 5333
    http:
        port: 8088
        tlsKey: __dirname + "/key.pem"
        tlsCert: __dirname + "/cert.pem"
    redis:
        socket: '127.0.0.1:6379'
        oldDNS:
            enabled: false # this will be enabled in the redis test
            ttl: 600
        blockchain:
            enabled: false # this will be enabled in the redis test
            ttl: 600
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

# set TEST_REAL_NAMECOIN environment variable to test with real namecoin instance
unless process.env.TEST_REAL_NAMECOIN
    nconf.overrides
        namecoin:
            config: __dirname + "/namecoin.conf"

    rpcMockServer = rpc.Server.$create()
    rpcMockServer.enableAuth (u,p) -> u is 'user' and p is 'password'
    rpcMockServer.expose 'name_show', (args, opt, cb) ->
        console.info "name_show path: %j".bold, args[0]
        data =
            'd/okturtles':
                name: 'd/okturtles'
                value: '{"email": "hi@okturtles.com", "ip": ["192.184.93.146"], "tls": {"sha1": ["5F:8B:74:78:4F:55:27:19:DC:53:6B:9B:C8:99:CD:91:8A:57:DD:07"], "enforce": "*"}}'
                txid: 'e3575debda4f4742f0a08b02c10f6d65b8f6607c9d821e75166bd9d223a5bfbe'
                address: 'N7ttEhc799upuaKBk8XvrVK66HvRSox6bi'
                expires_in: 25054
        cb null, (data[args[0]] || "404: Not Found")
    # listen on the port that's defined in support/namecoin.conf
    rpcMockServer.listen 8337, 'localhost'

module.exports =
    dnschain: require '../../src/lib/dnschain'
