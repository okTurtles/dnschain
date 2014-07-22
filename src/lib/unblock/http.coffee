###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

libProxy = require 'http-proxy'
module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"


    log = gNewLogger 'Unblock HTTP proxy'

    proxy = libProxy.createProxyServer {}
    proxy.on "error", (err, req, res) ->
        log.error "HTTP tunnel failed: "+req.headers.host
        res.writeHead 500
        res.end()
    {
        tunnel : (req, res) ->
            proxy.web req, res, {target: "http://"+req.headers.host, secure:false}
    }
