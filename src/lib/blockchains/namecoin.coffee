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

    # https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Regular_Expression
    VALID_NMC_DOMAINS = /^[a-z]([a-z0-9-]{0,62}[a-z0-9])?$/

    class NamecoinResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'NMC'
            @name = 'namecoin'
            @tld = 'bit'
            gFillWithRunningChecks @

        config: ->
            @log.debug "Loading #{@name} resolver"

            return unless gConf.add @name, _.map(_.filter([
                [process.env.APPDATA, 'Namecoin', 'namecoin.conf']
                [process.env.HOME, '.namecoin', 'namecoin.conf']
                [process.env.HOME, 'Library', 'Application Support', 'Namecoin', 'namecoin.conf']
                ['/etc/namecoin/namecoin.conf']]
            , (x) -> !!x[0])
            , (x) -> path.join x...), 'INI'

            @params = _.transform ["port", "connect", "user", "password"], (o,v) =>
                o[v] = gConf.chains[@name].get 'rpc'+v
            , {}
            @params.connect ?= "127.0.0.1"

            unless _(@params).values().every()
                missing = _.transform @params, ((o,v,k)->if !v then o.push 'rpc'+k), []
                @log.info "Disabled. Missing params:", missing
                return

            gConf.chains[@name].set 'host', @params.connect
            @

        start: ->
            @startCheck (cb) =>
                params = _.at @params, ["port", "connect", "user", "password"]
                # TODO: $create doesn't actually connect. you need to open a raw socket
                #       or an http socket and see if that works before declaring it works
                @peer = rpc.Client.$create(params...) or gErr "rpc create"
                @log.info "rpc to namecoind on: %s:%d", @params.connect, @params.port
                cb null

        resources:
            key: (property, operation, fmt, args, cb) ->
                if not operation?
                    result = @resultTemplate()
                    if S(property).endsWith(".#{@tld}") # namecoinize Domain
                        property = S(property).chompRight(".#{@tld}").s
                        if (dotIdx = property.lastIndexOf('.')) != -1
                            property = property.slice(dotIdx+1) #rm subdomain
                        if not VALID_NMC_DOMAINS.test property
                            err = new Error "Invalid Domain: #{property}"
                            err.httpCode = 400
                            return cb(err)
                        property = 'd/' + property
                    @log.debug gLineInfo("#{@name} resolve"), {property:property}
                    @peer.call 'name_show', [property], (err, ans) =>
                        if err
                            @log.error gLineInfo('name_show failed'), {property:property, errMsg:err.message}
                            cb err
                        else
                            try
                                ans.value = JSON.parse ans.value
                            catch e
                                @log.debug gLineInfo('bad JSON'), {value:ans.value, errMsg:e.message}
                            result.data = ans
                            cb null, result
                else
                    @log.debug gLineInfo "unsupported op #{operation} for prop: #{property}"
                    cb new Error "Not Implemented"
