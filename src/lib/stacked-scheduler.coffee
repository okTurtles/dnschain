###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# TODO: go through 'TODO's!

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k};"

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

            if @stackedDelay is 0 or diffMillis >= @stackedDelay
                process.nextTick callback
            else
                nonce = @taskCounter++
                
                cbAndCleanup = =>
                    delete @tasks[nonce]
                    callback()

                @tasks[nonce] =
                    callback: callback # for 'cancelAll'
                    tid: setTimeout(cbAndCleanup, diffMillis)