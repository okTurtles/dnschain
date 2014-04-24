###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

Transform = require('stream').Transform

# objectMode is one by default

module.exports = (dnschain) ->
    StackedScheduler = require('./stacked-scheduler')(dnschain)

    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    defaults =
        log         : newLogger 'RS'
        stackedDelay: 0
        resolver    : config.get 'dns:oldDNS'
        answerFilter: (a) -> a.address
        reqMaker    : (cname) ->
            dns2.Request
                question: dns2.Question {name:cname, type:'A'} # TODO: 'type' correct always?
                server: @resolver

    class ResolverStream extends Transform
        constructor: (@opts) ->
            @opts = _.cloneDeep @opts # clone these for safety in case outside code updates them
            @opts.objectMode ?= true
            defaultProps = _.keys defaults
            # copy property values in @opts for those keys in 'defaults' into this object
            _.assign @, _.pick(_.defaults(@opts, defaults), defaultProps)
            super _.omit @opts, defaultProps

            @scheduler  = new StackedScheduler @opts
            @requests   = {}
            @reqCounter = 0

        cancelRequests: (andStop=false) ->
            for id,req of @requests
                req.cancel()
                delete @requests[id]

            @scheduler.cancelAll()
            @push(null) if andStop

        _transform: (cname, encoding, callback) ->
            if typeof cname != 'string'
                tErr "cname isn't a string!", cname

            sig = "ResolverStream"
            req = @reqMaker(cname)
            answers = []
            success = false
            reqErr  = undefined

            req.on 'message', (err, answer) =>
                if err?
                    @log.error "should not have an error here!", {fn:sig+':error', err:err, answer:answer}
                    reqErr = new Error(util.format "message error for '%j': %j", cname, err)
                else
                    @log.debug "resolved %j => %j !", req.question, answer.answer, {fn:sig+':message', cname:cname}
                    success = true
                    answers.push answer.answer...
                    answer.answer.forEach (a) => @push(@answerFilter(a))

            req.on 'timeout', =>
                @log.debug {fn:sig+':timeout', q:req.question}
                reqErr = new Error(util.format "timeout for '%j': %j", cname, req)

            req.on 'error', (err) =>
                @log.warn {fn:sig+':error', q:req.question, err:err}
                reqErr = new Error(util.format "error for '%j': %j", cname, err)

            req.on 'end', =>
                delete @requests[req.rsReqID]
                if reqErr?
                    @log.warn "request failed", {fn:sig+'endCb', err:reqErr, req:req}
                    callback(reqErr)
                else
                    @emit('answers', answers) if success
                    callback()
                    # it is possible that neither 'success' is true
                    # nor is 'reqError' defined. This can happen
                    # when 'cancelRequests' is called on us.

            req.rsReqID = @reqCounter++

            @scheduler.schedule =>
                @requests[req.rsReqID] = req
                req.send()
