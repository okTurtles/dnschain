# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash-contrib'
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{TimeoutError} = Promise


# shutdown = (server, {wait}, done) ->
#     console.log "Waiting #{wait} second#{wait == 1 && ' ' || 's '}for DNSChain to shutdown".bold
#     server.shutdown -> setTimeout done, wait*1000

digBashAsync = ({parallelism, timeout, domain}, cb)->
    timeout ?= 500
    domain ?= 'apple.com'
    cmd = "dig @#{gConf.get 'dns:host'} -p #{gConf.get 'dns:port'} #{domain}"
    start = Date.now()
    Promise.map _.times(parallelism, -> cmd), (cmd, idx) ->
        console.log "STARTING dig #{idx}: #{cmd}".bold
        execAsync(cmd).bind({cmd:cmd, idx:idx, domain:domain}).spread (stdout) ->
            [__, status, ip] = stdout.match /status: ([A-Z]+)[^]+?IN\s+A\s+([\d\.]+)/m
            console.log "FINISHED dig #{idx}: status: #{status}: #{domain} => #{ip}".bold
            _.assign @, {time:Date.now() - start, status:status, ip:ip}
        .timeout(timeout, "TIMEOUT: dig #{idx}: #{cmd}")
        .catch (e) ->
            console.log "EXCEPTION: #{idx}|#{cmd}: #{e.message}".bold
            _.assign @, {err:e.name}
    # it's possible that one of the assertions in the callback will get triggered
    # so we use .done instead of .then because it propagates the error.
    .done (results) ->
        console.log "DONEv2 digBashAsync: #{JSON.stringify(results)}".bold
        cb null, results

describe 'rate limiting', ->
    this.timeout 6 * 1000
    server = null

    it 'should start with default settings', (done) ->
        console.log "START: default settings".bold
        server = new DNSChain()
        setTimeout done, 100 # wait for it to finish starting

    it 'should be ~200ms apart', (done) ->
        this.slow 600 # milliseconds
        digBashAsync {parallelism:2}, (err, results) ->
            results.should.have.length 2
            _.some(results, 'err').should.be.empty
            diff = Math.abs _(results).map('time').reduce (sum,n) -> sum - n
            console.log "Space between requests: #{diff}ms".bold
            diff.should.be.within(100, 400)
            done()

    it 'should drop all requests except for one', (done) ->
        this.slow 1000 # milliseconds
        digBashAsync {parallelism:5, domain:'google.com'}, (err, results) ->
            results.should.have.length(5)
            _(results).where('err').map('err').value().should.matchEach 'TimeoutError'
            _.where(results, 'status').should.have.length(1)
            done()

    it 'should fail', ->
        assert.throws -> throw new Error()
        (-> throw new Error()).should.throw()
        

    # it 'should limit blockchain DNS requests', ->

    # it 'should limit HTTP requests', ->

    # it 'should shutdown successfully', (done) ->
    #     this.slow 600
    #     shutdown server, wait:0.2, done

    # it 'should restart with custom settings', (done) ->
    #     console.log "START: custom settings".bold
    #     server = new DNSChain()
    #     setTimeout done, 100 # wait for it to finish starting

    # it 'should limit DNS requests', ->

    # it 'should limit HTTP requests', ->

    it 'should shutdown successfully', ->
        server.shutdown() # returns a promise. Mocha should handle that properly

        
