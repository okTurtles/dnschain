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

    # TODO: test starting with TLS cert missing. 

    it 'should start with default settings', (done) ->
        console.log "START: default settings".bold
        server = new DNSChain()
        setTimeout done, 100 # wait for it to finish starting


    it 'should fetch profile over HTTPS via IP', (done) ->
        # TODO: this
        
        done()

    it 'should shutdown successfully', ->
        server.shutdown() # returns a promise. Mocha should handle that properly
