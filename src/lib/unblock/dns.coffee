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

    dnsSettings = gConf.get "dns"
    log = gNewLogger "Unblock DNS Hijacker"

    {
        hijack : (req, res) ->
            res.answer.push dns2.A {
                name: req.question[0].name
                address: dnsSettings.externalIP
                ttl: 120
            }
            res.header.aa = 1
            res.send()
            log.debug gLineInfo "Hijacked "+req.question[0].name
            log.debug gLineInfo(), res.answer[0]
    }
