###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    BlockchainResolver = require('../blockchain.coffee')(dnschain)

    class KeyidResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'BDNS'
            @tld = 'p2p'
            @name = 'keyid'
            gFillWithRunningChecks @

        config: ->
            @log.debug "Loading #{@name} resolver"

            return unless gConf.add @name, _.map(_.filter([
                [process.env.APPDATA, 'KeyID', 'config.json'],
                [process.env.HOME, '.KeyID', 'config.json'],
                [process.env.HOME, 'Library', 'Application Support', 'KeyID', 'config.json']]
            , (x) -> !!x[0])
            , (x) -> path.join x...)

            @params = _.transform ["httpd_endpoint", "rpc_user", "rpc_password"], (o,v) =>
                o[v] = gConf.chains[@name].get 'rpc:'+v
            , {}

            unless _(@params).values().every()
                missing = _.transform @params, ((o,v,k)->if !v then o.push 'rpc:'+k), []
                @log.info "Disabled. Missing params:", missing
                return

            [@params.host, @params.port] = @params.httpd_endpoint.split ':'
            @params.port = parseInt @params.port
            gConf.chains[@name].set 'host', @params.host
            @

        start: ->
            @startCheck (success) =>
                params = _.at @params, ["port", "host", "rpc_user", "rpc_password"]
                # TODO: $create doesn't actually connect. you need to open a raw socket
                #       or an http socket and see if that works before declaring it works
                @peer = rpc.Client.$create(params...) or gErr "rpc create"
                @log.info "rpc to bitshares_client on: %s:%d/rpc", @params.host, @params.port
                success()

        resolve: (path, options, cb) ->
            result = @resultTemplate()
            @log.debug gLineInfo("#{@name} resolve"), {path:path}
            @peer.call 'dotp2p_show', [path], path:'/rpc', (err, ans) ->
                return cb(err) if err
                if _.isString ans
                    try
                        result.value = JSON.parse ans
                    catch e
                        @log.error glineInfo(e.message)
                        return cb e
                else if not _.isObject ans
                    @log.warn gLineInfo('type not string or object!'), {json: ans, type: typeof(ans)}
                    result.value = {}
                cb null, result

        dnsHandler: require('./namecoin').prototype.dnsHandler
