# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
net = require 'net'
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{lookup} = require './support/functions'

describe 'Basic blockchain support', ->
    server = null

    unless process.env.TEST_REAL_NAMECOIN or process.env.TEST_REAL_NXT
        console.info """
            To test with real blockchains, set the appropriate environment variables!
            Otherwise we will use mock responses.

            Ex:
                $ TEST_REAL_NAMECOIN=1 npm test
                $ TEST_REAL_NXT=1 npm test

                .. etc ..
        """.bold.yellow

    it 'should start DNSChain', ->
        (server = new DNSChain()).start()

    it '[Namecoin] should support .bit resolution', ->
        Promise.join(lookup('okturtles.bit'), lookup('dot-bit.bit')).then (res) ->
            console.info "[NMC] RESULTS: %s".bold, JSON.stringify res
            res[0].answer[0].address.should.equal '192.184.93.146'
            net.isIP(res[1].answer[0].address).should.be.ok

    it '[Namecoin] should lookup d/okturtles via RESTful API', ->
        console.log "Skipping because this is already done by test/https.coffee".bold

    it.skip '[NXT] should support .nxt resolution', ->
        console.log "TODO: THIS!".bold.yellow

    it.skip '[NXT] should lookup ?? via RESTful API', ->
        console.log "TODO: THIS!".bold.yellow

    it 'should stop DNSChain', ->
        server.shutdown()
