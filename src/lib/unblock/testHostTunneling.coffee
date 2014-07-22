###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

###
This file will become a full-fledged test suite with issue #12
###

http = require "http"
https = require "https"
tls = require "tls"

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

getPage = (protocol, ip, port, host, path, cb) ->
    data = ""
    req = protocol.request {
        hostname:ip
        port
        method: "GET"
        path
        headers: {
            host
        }
    }, (res) ->
        res.on "data", (chunk) ->
            data += chunk.toString "utf8"
        res.on "end", () ->
            cb null, data
    req.on "error", (err) ->
        cb err
    req.end()

connect = (host, port, text, cb) ->
    data = ""
    stream = tls.connect port, host
    stream.on "data", (chunk) ->
        data += chunk.toString "utf8"
    stream.on "end", () ->
        cb null, data
    stream.on "error", cb
    stream.write text, "utf8"
    stream.on "close", -> cb new Error "Closed too soon"

getPage https, "127.0.0.1", 443, "www.youtube.com", "/", (err, data) ->
    if (not err?) and data.indexOf("html") >= 0
        console.log "HTTPS Youtube works"
    else
        console.log err

getPage http, "127.0.0.1", 80, "www.youtube.com", "/", (err, data) ->
    if (not err?) and data.indexOf("html") >= 0
        console.log "HTTP Youtube works"
    else
        console.log err

getPage https, "127.0.0.1", 44555, "reddit.com", "/r/worldnews/", (err, data) ->
    if (not err?) and data.length > 10
        console.log "Host Tunneling works"
    else
        console.log err

