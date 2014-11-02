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

    class BDNSPeer
        constructor: (@dnschain) ->
            # @log = @dnschain.log.child server: "BDNS"
            @log = gNewLogger 'BDNS'
            @log.debug "Loading BDNSPeer..."
            
            get = gConf.bdns.get
            endpoint = get('rpc:httpd_endpoint')?.split ':'
            if endpoint?
                [host, port] = [endpoint[0], parseInt endpoint[1]]
                @peer = rpc.Client.$create port, host, get('rpc:rpc_user'), get('rpc:rpc_password')
                gErr "rpc $create bdns" unless @peer
                @log.info "rpc to bitshares_client on: %s:%d/rpc", host, port
            else
                @log.info 'BDNS disabled. (config.json not found)'

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug gLineInfo('bdns resolve'), {path:path}
            @peer.call 'dotp2p_show', [path], path:'/rpc', cb

        # TODO: this is a bit ugly... fix it.
        toJSONstr: (json) ->
            # @log.debug gLineInfo('json type'), {type: typeof json, json: json}
            if _.isObject json
                JSON.stringify json
            else if _.isString json
                json
            else
                @log.warn gLineInfo('type not object!'), {json: json, type: typeof(json)}
                JSON.stringify {}

        toJSONobj: (json) ->
            if _.isString json
                JSON.parse json
            else if _.isObject json
                json
            else
                @log.warn gLineInfo('type not string!'), {json: json, type: typeof(json)}
                {}
