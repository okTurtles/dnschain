###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###
module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # http://tools.ietf.org/html/rfc5246#section-7.4.1
    # http://stackoverflow.com/questions/17832592/extract-server-name-indication-sni-from-tls-client-hello
    class HTTPSUtils
        categories: {
            SNI : 0
            NO_SNI : 1
            NOT_HTTPS : 2
            INCOMPLETE : 3
        }

        parseHTTPS: (packet) ->
            res = {}
            try
                res.contentType = packet.readUInt8 0
                if res.contentType != 22 then return [@categories.NOT_HTTPS, {}]

                res.recordVersionMajor = packet.readUInt8 1
                if res.recordVersionMajor >= 7 then return [@categories.NOT_HTTPS, {}]

                res.recordVersionMinor = packet.readUInt8 2
                if res.recordVersionMinor >= 7 then return [@categories.NOT_HTTPS, {}]

                res.recordLength = packet.readUInt16BE 3

                res.handshakeType = packet.readUInt8 5
                if res.handshakeType != 1 then return [@categories.NOT_HTTPS, {}]

                res.handshakeLength = packet[6..8]
                res.handshakeVersion = packet.readUInt16BE 9
                res.random = packet[11..42]

                res.sessionIDlength = packet.readUInt8 43
                pos = res.sessionIDlength + 43 + 1

                res.cipherSuitesLength = packet.readUInt16BE pos
                pos += res.cipherSuitesLength + 2

                res.compressionMethodsLength = packet.readUInt8 pos
                pos += res.compressionMethodsLength + 1

                res.extensionsLength = packet.readUInt16BE pos
                pos += 2

                extensionsEnd = pos + res.extensionsLength - 1
                jump = 0

                res.extensions = {}

                while pos < extensionsEnd
                    ext = {}
                    ext.type = packet.readUInt16BE pos
                    ext.length = packet.readUInt16BE (pos+2)
                    jump = ext.length+4
                    ext.body = packet[pos..(pos+jump-1)]
                    res.extensions[ext.type] = ext
                    pos += jump

                if res.extensions["0"]?
                    sniPos = 0
                    sni = res.extensions["0"]
                    sni.sniType = sni.body.readUInt16BE 0
                    sni.sniLength = sni.body.readUInt16BE 2
                    sni.sniList = sni.body.readUInt16BE 4
                    sni.sniNameType = sni.body.readUInt8 6
                    sni.sniNameLength = sni.body.readUInt16BE 7
                    sni.sniName = sni.body[9..(9+sni.sniNameLength)]
                    res.host = sni.sniName.toString "utf8"
                    return [@categories.SNI, res]
                else
                    return [@categories.NO_SNI, {}]
            catch ex
                return [@categories.INCOMPLETE, {}]


        # Open a TCP socket to a remote host.
        getStream: (host, port, cb) ->
            try
                done = (err, s) ->
                    done = ->
                    cb err, s
                s = net.createConnection {host, port}, ->
                    done null, s
                s.on "error", (err) -> s.destroy()
                s.on "close", -> s.destroy()
                s.on "timeout", -> s.destroy()
            catch err
                done err

        # Received raw TCP data in chunked mode and attempt to extract Hello data
        # after every chunk. Return as soon as the Hello data has been obtained.
        getClientHello: (c, cb) ->
            received = []
            buf = new Buffer []
            done = (err, category, host, buf) ->
                c.removeAllListeners("data")
                done = ->
                cb err, category, host, buf
            c.on "data", (data) =>
                c.pause()
                received.push data
                buf = Buffer.concat received

                [category, parsed] = @parseHTTPS buf
                switch category
                    when @categories.SNI
                        done null, category, parsed.host, buf
                    when @categories.NO_SNI
                        done null, category, null, buf
                    when @categories.NOT_HTTPS
                        done new Error "NOT HTTPS", category, null, buf
                    when @categories.INCOMPLETE
                        c.resume()
                    else
                        done new Error "Unimplemented", category, null, buf
            c.on "timeout", ->
                c.destroy()
                done new Error "HTTPS getClientHello timeout"
            c.on "error", (err) ->
                c.destroy()
                done err
            c.on "close", ->
                c.destroy()
                done new Error "HTTPS socket closed"