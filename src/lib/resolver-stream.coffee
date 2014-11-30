###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

Transform = require('stream').Transform

# objectMode is on by default

module.exports = (dnschain) ->
    StackedScheduler = require('./stacked-scheduler')(dnschain)

    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    defaults =
        name        : 'RS'
        stackedDelay: 0
        resolver    : gConf.get 'dns:oldDNS'
        answerFilter: (a) -> a.address
        reqMaker    : (cname) ->
            dns2.Request
                question: dns2.Question {name:cname, type:'A'} # TODO: is type=A always correct?
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
            @errCount   = 0
            @log = gNewLogger @name

        cancelRequests: (andStop=false) ->
            @log.debug 'cancelling requests%s', if andStop then ' and stopping' else ''

            # cancell all active requests (those that were sent)
            for id,req of @requests
                @log.debug gLineInfo "cancelling req-#{req.rsReqID} (should have same id: #{id})"
                req.cancel()
                delete @requests[id]

            # cancell all pending requests (those to be sent)
            @scheduler.cancelAll()
            @stopped = andStop

        # 'callback' should only be called in req.on 'end'
        _transform: (cname, encoding, callback) ->
            if typeof cname != 'string'
                gErr "cname isn't a string!", cname

            if @stopped
                @log.debug gLineInfo("stopped. not scheduling req for '#{cname}'")
                return callback()

            req = @reqMaker(cname)
            req.rsReqID = @reqCounter++
            q = req.question
            answers = []
            success = false
            reqErr  = undefined

            reqErrFn = (code, msg...) =>
                reqErr = new Error util.format msg...
                reqErr.code = code
                @log.debug gLineInfo('reqErrfn'), reqErr.message
                @errCount += 1

            req.on 'message', (err, answer) =>
                if err
                    @log.error gLineInfo("should not have an error here!"), {err:err?.message, answer:answer, q:q}
                    reqErrFn NAME_RCODE.SERVFAIL, "msg err %j: %j", q, err.message ? err
                else
                    @log.debug gLineInfo("req-#{req.rsReqID} message"), {resolved_q:q, to:answer.answer}
                    if answer.answer.length > 0
                        success = true
                        answers.push answer.answer...
                        answer.answer.forEach (a) => @push @answerFilter a
                    else
                        reqErrFn NAME_RCODE.NOTFOUND, "cname not found: %j", cname

            req.on 'timeout', =>
                @log.debug gLineInfo("req-#{req.rsReqID} timeout"), {q:q}
                # TODO: better rcode value? am not aware of a timeout value
                #       https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml
                reqErrFn NAME_RCODE.SERVFAIL, "timeout for '%j': %j", cname, req

            req.on 'cancelled', =>
                @log.debug gLineInfo("req-#{req.rsReqID} cancelled"), {q:q}
                success = false

            req.on 'error', (err) =>
                @log.warn gLineInfo("req-#{req.rsReqID} error"), {q:q, err:err?.message}
                reqErrFn NAME_RCODE.SERVFAIL, "error for '%j': %j", cname, err

            req.on 'end', =>
                @log.debug gLineInfo("req-#{req.rsReqID} end"), {q:q, answers:answers, success:success}
                delete @requests[req.rsReqID]
                # it is possible that neither 'success' is true
                # nor is 'reqError' defined. This can happen
                # when 'cancelRequests' is called on us.
                if reqErr
                    @log.debug gLineInfo("req-#{req.rsReqID} failed"), {err:reqErr.message, q:q}
                    # we emit 'failed' instead of 'error' so that we can continue
                    # processing other `cname`s in the pipeline.
                    @emit 'failed', reqErr
                else if success
                    @emit 'answers', answers

                # we always call `callback` without an error value for the same reason that
                # that we emit 'failed' instead of 'error' (to continue processing)
                callback()

            @log.debug gLineInfo("scheduling req-#{req.rsReqID}"), {q:q, cname:cname}

            @scheduler.schedule =>
                # add it to the active requests when it's actually sent
                @requests[req.rsReqID] = req
                @log.debug gLineInfo("sending req-#{req.rsReqID}"), {q:q}
                req.send()
