#!/usr/bin/env coffee

###
To get code coverage report via coffee coverage:

TEST_REAL_NAMECOIN=1 log__level=warn mocha --require coffee-coverage/register --compilers coffee:coffee-script/register -R html-cov --bail test/ > coverage.html 
###

nconf = require 'nconf'
Bottleneck = require 'bottleneck'
rpc = require 'json-rpc2'
require 'winston' # for strong coloring

process.env.TEST_DNSCHAIN = "1"

if process.env.TEST_DNSCHAIN != "1"
    throw new Error "couldn't set process.env.TEST_DNSCHAIN!"

# We can test Redis with a real redis instance or with 'fakeredis':
# https://github.com/hdachev/fakeredis
# 
# By default we use fakeredis.
# Set the TEST_REAL_REDIS environment variable to test with real server.

if process.env.TRAVIS and process.env.CI
    console.info "Detected Travic CI!".bold
    # travis has support for redis
    process.env.TEST_REAL_REDIS = "1"

console.info "Setting up test environment...".bold

overrides =
    dns:
        port: 5333
        oldDNS:
            address: '192.184.93.146'
    http:
        port: 8088
        tlsKey: __dirname + "/key.pem"
        tlsCert: __dirname + "/cert.pem"
    redis:
        socket: '127.0.0.1:6379'
        oldDNS:
            ttl: 600
        blockchain:
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
    console.info "NOT testing real namecoin resolution. Using mock response instead!".bold.yellow
    overrides.namecoin = config: __dirname + "/namecoin.conf"

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
            'd/dot-bit':
                name: 'd/dot-bit'
                value: '{"info":{"description":"Dot-BIT Project - Official Website","registrar":"http://register.dot-bit.org"},"fingerprint":["30:B0:60:94:32:08:EC:F5:BE:DF:F4:BB:EE:52:90:2C:5D:47:62:46"],"ns":["ns0.web-sweet-web.net","ns1.web-sweet-web.net"],"map":{"":{"ns":["ns0.web-sweet-web.net","ns1.web-sweet-web.net"]}},"email":"register@dot-bit.org"}'
                txid: 'dd3db7a13fa577f3274617f043e818102cd994f086bc6b54e701c8c548a8d793'
                address: 'N8ohh8puHRUqa3hYxUcqhFcRyrbad8iYue'
                expires_in: 3388
        cb null, (data[args[0]] || "404: Not Found")
    # listen on the port that's defined in support/namecoin.conf
    rpcMockServer.listen 8337, 'localhost'

nconf.overrides overrides

module.exports =
    dnschain: require '../../src/lib/dnschain'
    overrides: overrides # passing this this makes it
                         # possible to override the overrides
                         # later on (see test/https.coffee for example)
