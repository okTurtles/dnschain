# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
nconf = require 'nconf'
fs = require 'fs'
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}, overrides} = require './support/env'

describe 'https', ->

    server = null
    blockchain = null
    port = gConf.get 'http:tlsPort'
    testData = /hi@okturtles.com/ # results should contain this
    httpSettings = gConf.get "http"

    it 'should start with default settings', (done) ->
        console.log "START: default settings".bold
        server = new DNSChain()
        setTimeout done, 100 # wait for it to finish starting

    it 'should have Namecoin blockchain available for testing', ->
        blockchain = server.chains.namecoin
        console.info "Using #{blockchain.name} for testing HTTPS.".bold

    it 'should fetch profile over HTTPS via IP', ->
        this.timeout = 5 * 1000
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

    it 'should fail when TLS cert is missing but key is not', ->
        fakePath = '/this/path/shouldnt/exist.pem'
        console.info "was   : #{httpSettings.tlsCert}".bold
        # yes, this is hackish, and it would be ideal to use
        #   gConf.set('http:tlsCert', fakePath)
        # But that doesn't work ... because nconf is lacking. So we do it this way instead.
        # I tried several other methods, and only this worked without breaking anything else.
        overrides.http.tlsCert = fakePath
        nconf.overrides overrides
        console.info "now is: #{gConf.get 'http:tlsCert'}".bold
        gConf.get('http:tlsCert').should.equal fakePath
        assert.throws ->
            try
                {dnschain} = require './support/env'
                (require '../src/lib/https')(dnschain)
            catch e
                # reset path so that future tests work OK
                overrides.http.tlsCert = httpSettings.tlsCert
                nconf.overrides overrides
                throw e

    # TODO: don't skip this once we've async-ified all the classes  
    it.skip 'should autogenerate missing certificate/key files', ->
        nodeVersion = process.versions.node.split('.').map (x) -> parseInt x
        if nodeVersion[0] is 0 and nodeVersion[1] <= 10
            console.warn "Need nodejs 0.12+ to run this test. Skipping!".bold.yellow
        else
            overrides.http.tlsCert = __dirname + "/support/_tmpCert.pem"
            overrides.http.tlsKey  = __dirname + "/support/_tmpKey.pem"
            nconf.overrides overrides
            gConf.get('http:tlsCert').should.equal overrides.http.tlsCert

            {dnschain} = require './support/env'
            (require '../src/lib/https')(dnschain)

            keyMaterial = _(overrides.http).pick(['tlsKey', 'tlsCert']).transform((o, v, k)->
                o[k] = { key:k, path:v, exists: fs.existsSync(v) }
            ).value()

            for f in _.where(keyMaterial, exists:true)
                console.info "Deleting temp file: #{f.path}".bold
                fs.unlinkSync f.path

            _.where(keyMaterial, exists:false).should.be.empty

            # reset
            overrides.http = httpSettings
            nconf.overrides overrides

    it 'should autogenerate certificate/key files', ->
        this.timeout = 10 * 1000
        keyMaterial =
            tlsCert: __dirname + "/support/_tmpCert.pem"
            tlsKey : __dirname + "/support/_tmpKey.pem"
        {dnschain} = require './support/env'
        genKeyCertPairAsync = Promise.promisify require('../src/lib/pem')(dnschain).genKeyCertPair

        genKeyCertPairAsync(keyMaterial.tlsKey, keyMaterial.tlsCert).then ->
            keyMaterial = _(keyMaterial).transform((o, v, k)->
                o[k] = { key:k, path:v, exists: fs.existsSync(v) }
            ).value()
            _.where(keyMaterial, exists:true).map (f)->
                console.info "Deleting temp #{f.key}: #{f.path}".bold
                fs.unlinkSync f.path
            _.where(keyMaterial, exists:false).should.be.empty
