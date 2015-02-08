###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# we don't 'use strict' because i really want to be able to use 'eval' to declare variables

# expose global dependencies, functions, and constants into our namespace
for k of require('./globals')(exports)
    eval "var #{k} = exports.globals.#{k};"

exports.createServer = (a...) -> new DNSChain a...

DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)
EncryptedServer = require('./https')(exports)
ResolverCache = require('./cache')(exports)

localhosts = ->
    _.uniq [
        "127.0.0.", "10.0.0.", "192.168.", "::1", "fe80::"
        gConf.get('dns:host'), gConf.get('http:host')
        gConf.get('dns:externalIP'), gExternalIP()
        _.map(gConf.chains, (c) ->
            c.get('host'))...
    ].filter (o)-> typeof(o) is 'string'

exports.DNSChain = class DNSChain
    constructor: ->
        @log = gNewLogger 'DNSChain'
        try
            chainDir = path.join __dirname, 'blockchains'
            @chains = _.omit(_.mapValues(_.indexBy(fs.readdirSync(chainDir), (file) =>
                S(file).chompRight('.coffee').s
            ), (file) =>
                chain = new (require('./blockchains/'+file)(exports)) @
                chain.config()
            ), (chain) =>
                not chain
            )
            @chainsTLDs = _.indexBy _.compact(_.map(@chains, (chain) ->
                return chain if chain.tld?
                return null
            )), 'tld'
            gConf.localhosts = localhosts.call @
            @dns = new DNSServer @
            @http = new HTTPServer @
            @encryptedserver = new EncryptedServer @
            @cache = new ResolverCache @
            @log.info "DNSChain started and advertising on: #{gConf.get 'dns:externalIP'}"

            if process.getuid() isnt 0 and gConf.get('dns:port') isnt 53 and require('tty').isatty(process.stdout)
                @log.warn "DNS port isn't 53!".bold.red, "While testing you should either run me as root or make sure to set standard ports in the configuration!".bold
        catch e
            @log.error "DNSChain failed to start: ", e.stack
            @shutdown()
            throw e # rethrow

    # callbacks must follows convention described here:
    # https://github.com/petkaantonov/bluebird/blob/master/API.md#promisepromisifyfunction-nodefunction--dynamic-receiver---function
    shutdown: (cb=->) ->
        servers = [@dns, @http, @encryptedserver, @cache].concat(_.values(@chains)).map (s, idx) =>
            if s
                new Promise (resolve) => s.shutdown resolve
            else
                @log.warn "Undefined server at index #{idx}"
                Promise.reject null
        # calls 'cb' when all servers finish shutting down (or fail to)
        Promise.settle(servers).then cb
