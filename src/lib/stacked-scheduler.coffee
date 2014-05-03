###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# TODO: go through 'TODO's!

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class StackedScheduler
        constructor: ({@stackedDelay}) ->
            @stackedDelay ?= 2000 # 2 seconds by default
            @tasks = {}
            @nextRunTime = Date.now()
            @taskCounter = 0

        cancelAll: (runCallback=false)->
            for key, task of @tasks
                clearTimeout(task.tid)
                task.callback() if runCallback
                delete @tasks[key]

        schedule: (callback) ->
            diffMillis = Date.now() - @nextRunTime
            @nextRunTime += diffMillis + @stackedDelay
            nonce = @taskCounter++
            
            cbAndCleanup = =>
                delete @tasks[nonce]
                callback()

            if diffMillis >= @stackedDelay or _.size(@tasks) is 0
                diffMillis = 0

            @tasks[nonce] =
                callback: callback # for 'cancelAll'
                tid: setTimeout cbAndCleanup, diffMillis
