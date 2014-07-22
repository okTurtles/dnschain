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

    unblockSettings = dnschain.globals.gConf.get "unblock"

    {
    	isHijacked : (domain) ->
	        name = domain.split "."
	        unblockSettings.domainList[name[-2..].join(".")] or unblockSettings.domainList[name[-3..].join(".")] or null
    }
