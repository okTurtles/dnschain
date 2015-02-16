# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{TimeoutError} = Promise

describe 'Basic blockchain support', ->
    server = null

    it 'should start DNSChain', ->
        (server = new DNSChain()).start()

    it 'should support .bit resolution', ->
        console.log "TODO: THIS!".bold.yellow
        
    it 'should lookup id/greg via RESTful API', ->
        console.log "TODO: THIS!".bold.yellow

    it 'should support .nxt resolution', ->
        console.log "TODO: THIS!".bold.yellow

    it 'should lookup ??', ->
        console.log "TODO: THIS!".bold.yellow

    it 'should stop DNSChain', ->
        # Promise.delay(500).then -> server.shutdown()
        server.shutdown()
