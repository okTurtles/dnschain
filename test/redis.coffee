# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
fs = require 'fs'
nconf = require 'nconf'
{dnschain: {DNSChain, globals: {gConf}}, overrides} = require './support/env'
{lookup} = require './support/functions'

domains = fs.readFileSync __dirname+'/support/domains.txt', encoding:'utf8'
domains = domains.split '\n' # domains, each half has one .bit domain
                             # and one domain that will fail to resolve
numDomains = domains.length/2
domains = [_.take(domains,numDomains), _.takeRight(domains,numDomains)]

testQueries = (idx, domains, times) ->
    times.splice idx, 0, {start: Date.now()}
    Promise.settle(domains.map lookup).then (results) ->
        # Only one domain in `domains.txt` is an invalid domain
        _(results).invoke('isRejected').countBy().value()['true'].should.equal 1
        times[idx].time = Date.now() - times[idx].start
        console.info "Test #{idx+1} took: #{times[idx].time} ms".bold

# we use this function to change the DNS server we're using to avoid timeouts
switchDNS = (newOldDNS) ->
    # This value was set in overrides so we have to change it like so
    overrides.dns.oldDNS.address = newOldDNS
    nconf.overrides overrides
    gConf.get('dns:oldDNS:address').should.equal newOldDNS
    console.info "Set oldDNS addres to: #{newOldDNS}".bold

describe 'Redis DNS cache', ->
    this.timeout 6 * 1000
    server = null
    testTimes = []
    dnsServer = [
        overrides.dns.oldDNS.address
        '8.8.8.8'
        '208.67.220.220' # secondary OpenDNS
        '8.8.4.4'
    ]

    it 'should start with default settings', ->
        this.slow 1000
        console.log "START: default settings".bold
        # these work and we don't need to do nconf.overrides
        # because these keys were not specified in env.coffee overrides
        gConf.set 'redis:oldDNS:enabled', false
        gConf.set 'redis:blockchain:enabled', false
        switchDNS dnsServer[1]
        (server = new DNSChain()).start()

    # time how long it takes to do a bunch of DNS requests
    it 'should measure non-redis DNS performance', ->
        this.slow 3000
        console.log "Pausing for 1s to avoid bottleneck...".bold
        Promise.delay(1000).then ->
            testQueries 0, domains[0], testTimes

    it 'should restart DNSChain successfully', ->
        server.shutdown().delay(100).then ->
            (server = new DNSChain()).start()

    # time how long it takes to do a bunch of DNS requests
    it 'should measure how long it takes to repeat queries with redis disabled', ->
        this.slow 3000
        switchDNS dnsServer[2]
        console.log "Pausing for 1s to avoid bottleneck...".bold
        Promise.delay(1000).then ->
            testQueries 1, domains[0], testTimes
        .then ->
            testTimes[1].time.should.be.lessThan testTimes[0].time + 400

    it 'should restart DNSChain successfully', ->
        this.slow 1500
        gConf.set 'redis:oldDNS:enabled', true
        gConf.set 'redis:blockchain:enabled', true
        switchDNS dnsServer[3]
        server.shutdown().delay(100).then ->
            (server = new DNSChain()).start()

    # make the same queries now 
    it 'should warm up with redis cache now enabled', ->
        this.slow 1000
        console.log "Pausing for 1s to avoid bottleneck...".bold
        Promise.delay(1000).then ->
            testQueries 2, domains[1], testTimes
        .then ->
            testTimes[2].time.should.be.approximately testTimes[1].time, 1000

    it 'should be significantly faster to repeat queries with redis enabled', ->
        this.slow 2000
        switchDNS dnsServer[0]
        console.log "Pausing for 1s to avoid bottleneck...".bold
        Promise.delay(1000).then ->
            testQueries 3, domains[1], testTimes
        .then ->
            # TODO: we add 100 to the times to make Travis less likely to fail.
            #       for whatever reason it seems these are poor tests....
            #       See: https://github.com/okTurtles/dnschain/issues/120
            testTimes[3].time.should.be.lessThan testTimes[0].time + 100
            testTimes[3].time.should.be.lessThan testTimes[1].time + 100
            testTimes[3].time.should.be.lessThan testTimes[2].time + 100

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

