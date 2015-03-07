###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

Packet = require('native-dns-packet')

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    BlockchainResolver = require('../blockchain.coffee')(dnschain)

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class IcannResolver extends BlockchainResolver
        constructor: (@dnschain) ->
            @log = gNewLogger 'ICANN'
            @name = 'icann'
            gFillWithRunningChecks @

        resources:
            key: (property, operation, fmt, args, cb) ->
                req = new Packet()
                result = @resultTemplate()
                @log.debug gLineInfo("#{@name} resolve"), {property:property, args:args}
                req.question.push dns2.Question {name: property, type: args.type if args?.type? and _.has NAME_QTYPE,args.type}
                @dnschain.dns.oldDNSLookup req, (code, packet) =>
                    if code
                        cb {code:code, name:RCODE_NAME[code]}
                    else
                        result.data = packet
                        cb null, result
