# Test using mocha.

assert = require 'assert'
Promise = require 'bluebird'
_ = require 'lodash-contrib'
exec = require('child_process').exec
execAsync = Promise.promisify exec
{dnschain: {DNSChain, globals: {gConf}}} = require './support/env'

shutdown = (server, wait, done) ->
    console.log "Waiting #{wait} second#{wait == 1 && ' ' || 's '}for DNSChain to shutdown".bold
    server.shutdown -> setTimeout done, wait*1000


dnsBashAsync = (parallelism, cb)->
    cmd = "dig @#{gConf.get 'dns:host'} -p #{gConf.get 'dns:port'} apple.com"
    start = Date.now()
    Promise.map _.times(parallelism, -> cmd), (cmd, idx) ->
        console.log "STARTING dig #{idx}: #{cmd}".bold
        execAsync(cmd).then (answer) ->
            console.log "FINISHED dig #{idx}: #{answer}".bold
            {item: cmd, idx: idx, time: Date.now() - start}
    .each (item) ->
        console.log "DONE dnsBashAsync: #{JSON.stringify(item)}".bold
    .then cb

describe 'rate limiting', ->
    this.timeout 60 * 1000 # 60 seconds
    server = null
    # console.log "START: default settings".bold
    # before (done) -> server = new DNSChain done

    it 'should start with default settings', (done) ->
        console.log "START: default settings".bold
        server = new DNSChain -> setTimeout done, 100

    it 'should limit traditional DNS requests', (done) ->
        # TODO: it breaks on parallelism of 10. Test expected
        #       behavior by adjusting the custom settings for bottleneck
        dnsBashAsync 2, done

    # it 'should limit blockchain DNS requests', ->

    # it 'should limit HTTP requests', ->

    # it 'should shutdown successfully', (done) ->
    #     shutdown server, 2, done

    # it 'should restart with custom settings', (done) ->
    #     console.log "START: custom settings".bold
    #     server = new DNSChain done

    # it 'should limit DNS requests', ->

    # it 'should limit HTTP requests', ->

    it 'should shutdown successfully', (done) ->
        shutdown server, 2, done

        
