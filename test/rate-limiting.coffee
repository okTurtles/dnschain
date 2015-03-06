# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
{dnschain: {DNSChain}} = require './support/env'
{digAsync} = require './support/functions'

describe 'rate limiting', ->
    this.timeout 10 * 1000
    server = null

    it 'should start with default settings', ->
        console.log "START: default settings".bold
        (server = new DNSChain()).start()

    it 'should be ~200ms apart', (done) ->
        this.slow 600 # milliseconds
        digAsync {parallelism:2}, (err, results) ->
            results.should.have.length 2
            _.some(results, 'err').should.be.empty
            diff = Math.abs _(results).map('time').reduce (sum,n) -> sum - n
            console.log "Space between requests: #{diff}ms".bold
            diff.should.be.within(90, 400) # I actually got an exception with b/c of a 94 ms diff!
                                           # TODO: @SGrondin figure out why it's so low.
            done()

    it 'should drop all requests except for one', (done) ->
        this.slow 5000 # milliseconds
        # we're using 'ssl-google-analytics.l.google.com' in order to also test
        # our currently (somewhat crappy) subdomain iteration mitigation
        # (since this domain has >3 parts to it).
        # See: https://github.com/okTurtles/dnschain/issues/107
        domain = 'ssl-google-analytics.l.google.com'
        Promise.delay(500).then ->
            digAsync {parallelism:5, domain:domain}, (err, results) ->
                results.should.have.length(5)
                errors = _(results).where(err:'TimeoutError').map('err').value()
                errors.should.matchEach 'TimeoutError'
                errors.should.have.length(4)
                done()

    it 'should succeed on all requests', (done) ->
        this.slow 3000 # milliseconds
        
        # different domains = complete parallelism
        domains = ['okturtles.org', 'eff.org', 'lobste.rs', 'taoeffect.com', 'twitter.com']
        counter = 0
        generator = -> domains[counter++]

        digAsync {parallelism:domains.length, domain:generator}, (err, results) ->
            results.should.have.length domains.length
            _.some(results, 'err').should.be.empty
            done()

    # it 'should limit blockchain DNS requests', ->

    # it 'should limit HTTP requests', ->

    it 'rate limiting should shutdown successfully', ->
        server.shutdown() # returns a promise. Mocha should handle that properly
