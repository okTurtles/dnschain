# Test using mocha.

assert = require 'assert'
should = require 'should'
Promise = require 'bluebird'
_ = require 'lodash'
nconf = require 'nconf'
fs = require 'fs'
os = require 'os'
request = require 'superagent'
getAsync = Promise.promisify request.get
execAsync = Promise.promisify require('child_process').exec
{dnschain: {DNSChain, globals: {gConf}}, overrides} = require './support/env'

MACOSX = os.platform() is 'darwin'

describe 'https', ->

    server = null
    blockchain = null
    port = gConf.get 'http:tlsPort'
    testData = /hi@okturtles.com/ # results should contain this
    httpSettings = gConf.get "http"
    this.timeout 20 * 1000

    it 'should start with default settings', ->
        console.log "START: default settings".bold
        (server = new DNSChain()).start()

    it 'should have Namecoin blockchain available for testing', ->
        blockchain = server.chains.namecoin
        console.info "Using #{blockchain.name} for testing HTTPS.".bold

    it 'should fetch profile over HTTPS via IP & HOST: namecoin.dns', ->
        cmd = "curl -i -k -H \"Host: namecoin.dns\" https://127.0.0.1:#{port}/d/okturtles"
        console.info "Executing: #{cmd}".bold
        execAsync(cmd).spread (stdout) ->
            console.info "Result: #{stdout}".bold
            stdout.should.match testData

    it 'should fetch profile over HTTPS via SNI via namecoin metaTLD', ->
        this.slow 5 * 1000
        cmd = "curl -i -k -H \"Host: namecoin.dns\" --resolve namecoin.dns:#{port}:127.0.0.1 https://namecoin.dns/d/okturtles"
        console.info "Executing: #{cmd}".bold
        execAsync(cmd).spread (stdout) ->
            console.info "Result: #{stdout}".bold
            stdout.should.match testData
        .catch (e) ->
            if MACOSX
                throw e # re-throw; on this platform it should work
            else
                console.warn "Ignoring error because curl might be broken on #{os.platform()}. Error: #{e.message}".bold.yellow
                Promise.resolve() # return a "successful" result

    it 'should fetch fingerprint over HTTP', ->
        getAsync("http://localhost:#{gConf.get 'http:port'}/v1/resolver/fingerprint").then (res) ->
            res.header['content-type'].should.containEql 'application/json'
            res.body.fingerprint.should.equal '51:B1:DA:83:D2:97:2D:69:5B:F6:07:27:37:D6:1F:7A:BA:57:23:4C:5B:87:20:FD:4D:3B:AC:E9:1C:DB:F7:18'
            console.info "OK: #{res.request.url}".bold

    it 'should fetch icann.dns data', ->
        cmd = "curl -i -k -H \"Host: icann.dns\" https://127.0.0.1:#{port}/okturtles.org"
        console.info "Executing: #{cmd}".bold
        data = "\"address\":\"192.184.93.146\""
        execAsync(cmd).spread (stdout) ->
            console.info "Result: #{stdout}".bold
            stdout.should.containEql data

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

    it 'should autogenerate missing certificate/key files', ->
        keyMaterial =
            tlsCert: __dirname + "/support/_tmpCert.pem"
            tlsKey : __dirname + "/support/_tmpKey.pem"
        _.merge overrides.http, keyMaterial
        nconf.overrides overrides
        gConf.get('http:tlsCert').should.equal overrides.http.tlsCert

        {dnschain} = require './support/env'
        EncryptedServer = (require '../src/lib/https')(dnschain)
        tlsServer = new EncryptedServer server
        tlsServer.start().then ->
            keyMaterial = _(keyMaterial).transform((o, v, k)->
                o[k] = { key:k, path:v, exists: fs.existsSync(v) }
            ).value()
            _.where(keyMaterial, exists:true).map (f)->
                console.info "Deleting temp #{f.key}: #{f.path}".bold
                fs.unlinkSync f.path
            _.where(keyMaterial, exists:false).should.be.empty

            # reset
            overrides.http = httpSettings
            nconf.overrides overrides

            tlsServer.shutdown()

    ###
    # Test below is skipped because the one above is superior and now works
    it 'should generate certificate/key files', ->
        keyMaterial =
            tlsCert: __dirname + "/support/_tmpCert.pem"
            tlsKey : __dirname + "/support/_tmpKey.pem"
        {dnschain} = require './support/env'
        pem = require('../src/lib/pem')(dnschain)
        pem.genKeyCertPair(keyMaterial.tlsKey, keyMaterial.tlsCert).then ->
            keyMaterial = _(keyMaterial).transform((o, v, k)->
                o[k] = { key:k, path:v, exists: fs.existsSync(v) }
            ).value()
            _.where(keyMaterial, exists:true).map (f)->
                console.info "Deleting temp #{f.key}: #{f.path}".bold
                fs.unlinkSync f.path
            _.where(keyMaterial, exists:false).should.be.empty
    ###
