# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
net = require 'net'
request = require 'superagent'
getAsync = Promise.promisify request.get
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'
{lookup} = require './support/functions'

describe 'Basic datastore support', ->
    server = null
    port = gConf.get 'http:port'

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
        getAsync("http://localhost:#{port}/v1/namecoin/key/d%2Fokturtles").then (res) ->
            res.header['content-type'].should.containEql 'application/json'
            res.body.header.datastore.should.equal 'namecoin'
            res.body.value.email.should.equal 'hi@okturtles.com'
            console.info "OK: #{res.request.url}".bold

    it.skip '[NXT] should support .nxt resolution', ->
        console.log "TODO: THIS!".bold.yellow

    it.skip '[NXT] should lookup ?? via RESTful API', ->
        console.log "TODO: THIS!".bold.yellow

    it '[ICANN] should lookup okturtles.com via RESTful API', ->
        a1 = getAsync "http://localhost:#{port}/v1/icann/key/okturtles.com"
        a2 = getAsync "http://localhost:#{port}/v1/icann/key/okturtles.com.json"
        Promise.all([a1,a2]).each (res) ->
            res.header['content-type'].should.containEql 'application/json'
            res.body.header.datastore.should.equal 'icann'
            _.find(res.body.value.answer, {address: '192.184.93.146'}).should.be.ok
            console.info "OK: #{res.request.url}".bold

    it 'should fail for non-existent RESTful resources', (done) ->
        request.get("http://localhost:#{port}/v1/namecoin/junk/d%2Fokturtles").end (err, res) ->
            res.statusType.should.equal 4
            res.text.should.containEql "Unsupported"
            console.info "Should fail: #{res.request.url}".bold
            done()

    it 'should stop DNSChain', ->
        server.shutdown()
