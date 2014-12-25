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

    class NXTPeer
        constructor: (@dnschain) ->
            @log = gNewLogger 'NXT'
            @log.debug "Loading NXTPeer..."
            
            # we want them in this exact order:
            params = ["port", "connect"].map (x)-> gConf.nxt.get x
            
            @peer = 'http://' + params[1] + ":" + params[0] + '/nxt?requestType=getAlias&aliasName=' 
            @log.info "Nxt API on: %s:%d", params[1], params[0]

        shutdown: ->
            @log.debug 'shutting down!'
            # @peer.end() # TODO: fix this!

        resolve: (path, cb) ->
            @log.debug {fn: 'resolve', path: path}
            req = http.get @peer + path, (res) ->
                data = ''
                res.on 'data', (chunk) ->
                    data += chunk.toString()
                res.on 'end', () ->
                    data = JSON.parse data
                    data.value = data.aliasURI
                    cb(null, data)
             req.on 'error', ->
                 cb()

        toJSONstr: (json) -> json.value
        toJSONobj: (json) -> JSON.parse json.value