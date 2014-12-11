###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# we don't 'use strict' because i really want to be able to use 'eval' to declare variables

###

design:

- configuration:
    - local in ~/.dnschain
    - global in /etc/dnschain
    - support command line providing configuration (overrides both of the above)
    - options:
        - everything in exports.defaults
        - logging options for bunyan

- usage
    - systemd background daemon
    - CLI usage for quick testing

- code
    - design code in a modular library-friendly way in case
      someone wants to use DNSChain in a library or to have multiple DNSChain
      servers on the same machine (for whatever reason).


security:

- protect against DDoS DNS amplification attacks. 

DNS libraries used and considered:

- dns : nodejs' dns (currently lacks ability to specify dns server for query)
- dns2: native-dns (to be merged into nodejs in the future, according to author.
        used for specifying dns servers per query)
- dnsd: well-maintained dns server. I am holding off on using it for the sake of
        simplicity(single API), but if we discover a lacking server funcionality
        in native-dns, we'll switch to it for that purpose.

###

# expose global dependencies, functions, and constants into our namespace
for k of require('./globals')(exports)
    eval "var #{k} = exports.globals.#{k};"

exports.createServer = (a...) -> new DNSChain a...

NMCPeer = require('./nmc')(exports)
BDNSPeer = require('./bdns')(exports)
DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)
EncryptedServer = require('./https')(exports)

exports.DNSChain = class DNSChain
    constructor: ->
        @log = gNewLogger 'DNSChain'
        try
            @nmc = new NMCPeer @
            @bdns = new BDNSPeer @
            @dns = new DNSServer @
            @http = new HTTPServer @
            @EncryptedServer = new HTTPSServer @
            @log.info "DNSChain started and advertising on: #{gConf.get 'dns:externalIP'}"

            if process.getuid() isnt 0 and gConf.get('dns:port') isnt 53 and require('tty').isatty(process.stdout)
                @log.warn "DNS port isn't 53!".bold.red, "While testing you should either run me as root or make sure to set standard ports in the configuration!".bold
        catch e
            @log.error "DNSChain failed to start: ", e.stack
            @shutdown()
            throw e # rethrow

    shutdown: -> [@nmc, @dns, @http, @EncryptedServer].forEach (s) -> s?.shutdown?()

