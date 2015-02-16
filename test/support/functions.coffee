###

dnschain
http://dnschain.net

Copyright (c) 2015 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

Promise = require 'bluebird'
_ = require 'lodash'
dns = require 'native-dns'
{dnschain: {globals: {gConf}}} = require './env'
{Question, Request, consts} = dns

execAsync = Promise.promisify require('child_process').exec

module.exports =
    lookup: (domain) ->
        timeout = 2000
        new Promise (resolve, reject) ->
            req = Request
                question: dns.A {name:domain}
                server: {address:'127.0.0.1', port:gConf.get('dns:port'), type:'udp'}
                timeout: timeout
            req.on 'timeout', ->
                console.warn "#{domain} req timed out!".bold.yellow
                reject new Promise.TimeoutError()
            req.on 'error', (err) -> reject err
            req.on 'message', (err, ans) -> resolve ans
            console.info "Querying: #{domain}...".bold.blue
            req.send()
        .then (res) ->
            answer = res.answer[0]?.address || res.answer[0].data
            console.info "Success: #{domain}: #{answer}".bold
            res
        .catch (e) ->
            console.error "Fail: #{domain}: #{e.message}".bold.red
            throw e

    digAsync: ({parallelism, timeout, domain}, cb)->
        timeout ?= 2000
        domain ?= 'apple.com'
        genDomain = if _.isString(domain) then (-> domain) else domain
        command = ->
            "dig @#{gConf.get 'dns:host'} -p #{gConf.get 'dns:port'} #{genDomain()}"

        start = Date.now()
        Promise.map _.times(parallelism, command), (cmd, idx) ->
            console.log "STARTING dig #{idx}: #{cmd}".bold
            domain = cmd.split(' ')[-1..][0]
            execAsync(cmd).bind({cmd:cmd, idx:idx, domain:domain}).spread (stdout) ->
                [__, status, ip] = stdout.match /status: ([A-Z]+)[^]+?IN\s+A\s+([\d\.]+)/m
                console.log "FINISHED dig #{idx}: status: #{status}: #{@domain} => #{ip}".bold
                _.assign @, {time:Date.now() - start, status:status, ip:ip}
            .timeout(timeout, "TIMEOUT: dig #{idx}: #{cmd}")
            .catch (e) ->
                console.log "EXCEPTION: #{idx}|#{cmd}: #{e.message}".bold
                _.assign @, {err:e.name}
        # it's possible that one of the assertions in the callback will get triggered
        # so we use .done instead of .then because it propagates the error.
        .done (results) ->
            console.log "DONEv2 digAsync: #{JSON.stringify(results)}".bold
            cb null, results
