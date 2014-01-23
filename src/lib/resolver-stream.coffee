###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

Transform = require('stream').Transform
StackedScheduler = require('./stacked-scheduler')

# objectMode is one by default

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k};"

    defaults =
        log         : dnsnmc.log
        stackedDelay: 0
        resolver    : dnsnmc.defaults.dnsOpts.fallbackDNS
        answerFilter: (a) -> a.address
        reqMaker    : (cname) ->
            dns2.Request
                question: dns2.Question {name:cname, type:'A'}
                server: @resolver

    class ResolverStream extends Transform
        constructor: (@opts) ->
            @opts = _.cloneDeep @opts # clone these for safety in case outside code updates them
            @opts.objectMode ?= true
            defaultProps = _.keys(defaults)
            # copy property values in @opts for those keys in 'defaults' into this object
            _.merge @, _.pick(_.defaults(@opts, defaults), defaultProps)
            super _.omit(@opts, defaultProps)

            @scheduler  = new StackedScheduler @opts
            @requests   = {}
            @reqCounter = 0

        cancelRequests: (andStop=false) ->
            for id,req of @requests
                req.cancel()
                delete @requests[id]

            @scheduler.cancelAll()
            @push(null) if andStop

        _transform: (cnames, encoding, callback) ->
            cnames = [cnames] if typeof cnames is 'string'
            cnames.forEach (cname) =>
                req = @reqMaker(cname)
                success = false
                reqErr  = undefined

                req.on 'message', (err, answer) =>
                    if !err? and answer.answer.length > 0
                        success = true
                        @emit 'answer', answer
                        answer.answer.forEach (a) => @push(@answerFilter(a))
                    else
                        reqErr = new Error(util.format "message error for '%j': %j", cname, err)

                req.on 'timeout', =>
                    reqErr = new Error(util.format "timeout for '%j': %j", cname, req)

                req.on 'error', (err) =>
                    reqErr = new Error(util.format "error for '%j': %j", cname, err)

                req.on 'end', =>
                    delete @requests[req.rsReqID]
                    if success
                        callback()
                    else
                        reqErr ?= new Error('unknown error')
                        @log.warn {fn:'_transform->end', err:reqErr, req:req}, "request failed"
                        callback(reqErr)


                req.rsReqID = @reqCounter++

                @scheduler.schedule =>
                    @requests[req.rsReqID] = req
                    req.send()
