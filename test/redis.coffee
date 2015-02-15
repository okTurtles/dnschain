# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
fs = require 'fs'
dns = require 'native-dns'
nconf = require 'nconf'
{Question, Request, consts} = dns
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{TimeoutError} = Promise

domains = fs.readFileSync __dirname+'/support/domains.txt', encoding:'utf8'
domains = domains.split '\n'

lookup = (domain) ->
    timeout = 2000
    new Promise (resolve, reject) ->
        req = Request
            question: dns.A {name:domain}
            server: {address:'127.0.0.1', port:gConf.get('dns:port'), type:'udp'}
            timeout: timeout
        req.on 'timeout', ->
            console.warn "#{domain} req timed out!".bold.yellow
            reject new Promise.TimeoutError()
        req.on 'error', (err) -> reject err
        req.on 'message', (err, ans) -> resolve ans
        console.info "Querying: #{domain}...".bold.blue
        req.send()
    .then (res) ->
        answer = res.answer[0].address || res.answer[0].data
        console.info "Success: #{domain}: #{answer}".bold
        res
    .catch (e) ->
        console.error "Fail: #{domain}: #{e.message}".bold.red
        throw e

testQueries = (idx, times) ->
    times.splice idx, 0, {start: Date.now()}
    Promise.settle(domains.map lookup).then (results) ->
        # Only one domain in `domains.txt` is an invalid domain
        _(results).invoke('isRejected').countBy().value()['true'].should.equal 1
        times[idx].time = Date.now() - times[idx].start
        console.info "Test #{idx+1} took: #{times[idx].time} ms"

describe 'Redis DNS cache', ->
    this.timeout 6 * 1000
    server = null
    testTimes = []

    it 'should start with default settings', (done) ->
        this.slow 1000
        console.log "START: default settings".bold
        gConf.set 'redis:oldDNS:enabled', false
        gConf.set 'redis:blockchain:enabled', false
        server = new DNSChain()
        server.start()

    # time how long it takes to do a bunch of DNS requests
    it 'should measure non-redis DNS performance', ->
        this.slow 2000
        testQueries 0, testTimes

    it 'should restart DNSChain successfully', ->
        server.shutdown().delay(100).then ->
            server = new DNSChain()
            server.start()

    # time how long it takes to do a bunch of DNS requests
    it 'should measure how long it takes to repeat queries with redis disabled', ->
        this.slow 2000
        console.log "Pausing for 500ms to avoid bottleneck...".bold
        Promise.delay(500).then ->
            testQueries 1, testTimes
        .then ->
            testTimes[1].time.should.be.approximately testTimes[0].time, 500

    it 'should restart DNSChain successfully', ->
        this.slow 1500
        # these work and we don't need to do nconf.overrides
        # because these keys were not specified in env.coffee overrides
        gConf.set 'redis:oldDNS:enabled', true
        gConf.set 'redis:blockchain:enabled', true
        server.shutdown().delay(100).then ->
            server = new DNSChain()
            server.start()

    # make the same queries now 
    it 'should warm up with redis cache now enabled', ->
        this.slow 1000
        console.log "Pausing for 500ms to avoid bottleneck...".bold
        Promise.delay(500).then ->
            testQueries 2, testTimes
        .then ->
            testTimes[2].time.should.be.approximately testTimes[1].time, 500

    it 'should be significantly faster to repeat queries with redis enabled', ->
        this.slow 2000
        console.log "Pausing for 1s to avoid bottleneck...".bold
        Promise.delay(1000).then ->
            testQueries 3, testTimes
        .then ->
            # compare against "warmed up" redis-disabled time
            # we even add 10 milliseconds to "prove" it's faster
            (testTimes[3].time+10).should.be.lessThan testTimes[1].time

    it 'should shutdown successfully', ->
        server.shutdown() # returns a promise. Mocha should handle that properly

describe 'Redis HTTP API cache', ->

    # time how long it takes to do a bunch of DNS requests
    it.skip 'should measure non-redis HTTP API performance', ->
        console.warn "TODO: this test!".bold.yellow

    # time how long it takes to do a bunch of DNS requests
    it.skip 'should measure how long it takes to repeat queries with redis disabled', ->
        console.warn "TODO: this test!".bold.yellow

    # make the same queries now 
    it.skip 'should be significantly faster to repeat queries with redis enabled', ->
        console.warn "TODO: this test!".bold.yellow

