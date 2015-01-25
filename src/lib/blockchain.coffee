###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

###

INSTRUCTIONS:

    1. Copy this file and rename it to your blockchain's name.
       The name you choose will also be your metaTLD (e.g. namecoin.coffee => namecoin.dns)
    2. Rename the class (following the same naming convention as shown in
       `blockchains/namecoin.coffee`) and `extend BlockchainResolver`
    3. Uncomment and edit the code as appropriate. 
       Look at how the other blockchains do it (especially namecoin.coffee) 

    REMEMBER: When in doubt, look at `blockchains/namecoin.coffee` !

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # BlockchainResolver = require('../blockchain.coffee')(dnschain)
    # ResolverStream  = require('../resolver-stream')(dnschain)

    # These are potentially useful for the `dnsHandler:` method.
    # See namecoin.coffee for example usage.
    
    # QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    # NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    # NAME_RCODE = dns2.consts.NAME_TO_RCODE
    # RCODE_NAME = dns2.consts.RCODE_TO_NAME

    class BlockchainResolver # extends BlockchainResolver
        constructor: (@dnschain) ->
            # Uncomment and fill these in as appropriate:
            # @log = gNewLogger 'YourChainName'
            # @tld = 'chn'            # Your chain's TLD
            # @name = 'templatechain' # Your chain's name (no spaces)
            # @cacheTTL = 600         # How long Redis should cache entries in seconds
            #                         # 0 == no cache, override here

        # This is the default TTL value for all blockchains.
        # Override it above in the constructor for your blockchain. 
        cacheTTL: gConf.get 'redis:blockchain:ttl'

        # return @(this) upon successful load, falsy otherwise
        config: ->
            @log.debug "Loading #{@name} resolver"
            # Fill this in with code to load your config.
            # We recommend copying and editing the stuff from namecoin.coffee 
            # 
            # if "loaded successfully"
            #     return `@`
            # else
            #     return falsy value!

        # Close connection to your blockchain and do any other cleanup,
        # and only then call the callback (if one was passed in).
        shutdown: (cb) ->
            @log.debug 'shutting down!'
            cb?()

        # cb takes (error, resultObject)
        resolve: (path, options, cb) ->
            @log.debug gLineInfo("#{@name} resolve"), {path:path, options:options}
            result = @resultTemplate()

            # Example of what this function should do.
            # Uncomment and edit:
            
            # myBlockchain.resolve path, (err, answer) ->
            #     if err
            #         cb err
            #     else
            #         result.value = JSON.parse answer
            #         cb null, result


        # You should not modify the result template itself,
        # instead set its .value property accordingly in `resolve:` above.
        # See how other blockchains do it.
        resultTemplate: ->
            version: '0.0.1'
            header:
                blockchain: @name
            value: {}

        # http.coffee uses this to test whether to call the `resolve:` method
        validRequest: (path) -> true

        # Should be a dictionary of functions corresponding to traditional DNS
        # record types. See namecoin.coffee for an example. 
        dnsHandler: {}
