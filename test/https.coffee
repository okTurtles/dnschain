# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash-contrib'
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{TimeoutError} = Promise

describe 'https', ->

    server = null
    blockchain = null
    port = gConf.get 'http:tlsPort'
    testData = /hi@okturtles.com/ # results should contain this

    it 'should start with default settings', (done) ->
        console.log "START: default settings".bold
        server = new DNSChain()
        setTimeout done, 100 # wait for it to finish starting

    it 'should have Namecoin blockchain available for testing', ->
        blockchain = server.chains.namecoin
        console.info "Using #{blockchain.name} for testing HTTPS.".bold

    it 'should fetch profile over HTTPS via IP', ->
        cmd = "curl -i -k -H \"Host: namecoin.dns\" https://127.0.0.1:#{port}/d/okturtles"
        console.info "Executing: #{cmd}".bold
        execAsync(cmd).spread (stdout) ->
            console.info "Result: #{stdout}".bold
            stdout.should.match testData

    it 'should fetch profile over HTTPS via SNI', ->
        cmd = "curl -i -k -H \"Host: namecoin.dns\" --resolve namecoin.dns:#{port}:127.0.0.1 https://namecoin.dns/d/okturtles"
        console.info "Executing: #{cmd}".bold
        execAsync(cmd).spread (stdout) ->
            console.info "Result: #{stdout}".bold
            stdout.should.match testData

    it 'should fetch fingerprint over HTTP', ->
        console.warn "TODO: fetch fingerprint via API".bold.red

    it 'should shutdown successfully', ->
        server.shutdown() # returns a promise. Mocha should handle that properly

    it 'should fail because TLS cert is missing', ->
        nconf = require 'nconf'
        savedPath = gConf.get 'http:tlsCert'
        fakePath = '/this/path/shouldnt/exist.pem'
        console.info "was: #{savedPath}".bold
        nconf.overrides http: tlsCert: fakePath
        console.info "now is: #{gConf.get 'http:tlsCert'}".bold
        gConf.get('http:tlsCert').should.equal fakePath
        assert.throws ->
            try
                {dnschain} = require './support/env'
                (require '../src/lib/https')(dnschain)
            catch e
                console.info e.stack
                # reset path so that future tests work OK
                nconf.overrides http: tlsCert: savedPath
                throw e
