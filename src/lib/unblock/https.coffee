###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

net = require "net" # TODO: Fix this, it's in the globals.

parse2Bytes = (buf) -> (buf[0] << 8) | buf[1]

categories = {
    SNI : 0
    NO_SNI : 1
    NOT_HTTPS : 2
    INCOMPLETE : 3
}

# http://tools.ietf.org/html/rfc5246#section-7.4.1
# http://stackoverflow.com/questions/17832592/extract-server-name-indication-sni-from-tls-client-hello
parseHTTPS = (packet) ->
    res = {}
    try
        res.contentType = packet.readUInt8 0
        if res.contentType != 22 then return [categories.NOT_HTTPS, {}]

        res.recordVersionMajor = packet.readUInt8 1
        if res.contentType >= 7 then return [categories.NOT_HTTPS, {}]

        res.recordVersionMinor = packet.readUInt8 2
        if res.contentType >= 7 then return [categories.NOT_HTTPS, {}]

        res.recordLength = parse2Bytes packet.readUInt16BE 3

        res.handshakeType = packet.readUInt8 5
        if res.contentType != 1 then return [categories.NOT_HTTPS, {}]

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
        res.type = -1
        res.length = 0

        # Loop over extension blocks until we find the SNI block
        while res.type != 0 and pos < extensionsEnd
            pos += res.length
            res.type = packet.readUInt16BE pos
            res.length = packet.readUInt16BE (pos+2)

        res.SNIlength = packet.readUInt16BE (pos+4)
        res.serverNameType = packet.readUInt8 (pos+6)

        pos += 7
        # The SNI type number is 0. An SNI length shorter than 4 bytes indicates an invalid header.
        if res.type == 0 and res.SNIlength >= 4
            res.hostLength = packetreadUInt16BE pos
            pos += 2
            sliced = packet[pos..(pos+res.hostLength-1)]
            if sliced.length != hostLength then throw new Error "Incomplete"
            res.host = sliced.toString "utf8"
            return [categories.SNI, res]
        else
            return [categories.NO_SNI, {}]

    catch ex
        return [categories.INCOMPLETE, {}]


# Open a TCP socket to a remote host.
getStream = (host, port, cb) ->
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
getClientHello = (c, cb) ->
    received = []
    buf = new Buffer []
    done = (err, host, buf) ->
        c.removeAllListeners("data")
        done = ->
        cb err, host, buf
    c.on "data", (data) ->
        c.pause()
        received.push data
        buf = Buffer.concat received

        [category, parsed] = parseHTTPS buf
        if category == categories.SNI
            done null, parsed.host, buf
        else if category == categories.NO_SNI
            c.destroy()
            done new Error "No SNI found"
        else if category == categories.NOT_HTTPS
            # This needs to be sent to the internal TLS
            # server for decryption
            done new Error "No TLS support for now"
        else if category == categories.INCOMPLETE
            c.resume()
        else
            done new Error "Unimplemented"
    c.on "timeout", ->
        c.destroy()
        done new Error "HTTPS getClientHello timeout"
    c.on "error", (err) ->
        c.destroy()
        done err
    c.on "close", ->
        c.destroy()
        done new Error "HTTPS socket closed"

module.exports = {getClientHello, getStream}
