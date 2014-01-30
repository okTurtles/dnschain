###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# we don't 'use strict' because i really want to be able to use 'eval' to declare variables

###

design:

- configuration:
    - local in ~/.dnsnmc
    - global in /etc/dnsnmc
    - support command line providing configuration (overrides both of the above)
    - options:
        - everything in exports.defaults
        - logging options for bunyan

- usage
    - systemd background daemon
    - CLI usage for quick testing

- code
    - design code in a modular library-friendly way in case
      someone wants to use DNSNMC in a library or to have multiple DNSNMC
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

exports.createServer = (a...) -> new DNSNMC a...

NMCPeer = require('./nmc')(exports)
DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)

exports.DNSNMC = class DNSNMC
    constructor: ->
        @log = newLogger 'DNSNMC'
        try
            @nmc = new NMCPeer @
            @dns = new DNSServer @
            @http = new HTTPServer @
            @log.info "DNSNMC started with externalIP: ", externalIP()
        catch e
            @log.error "dnsnmc failed to start: ", e
            @shutdown()
            throw e # rethrow

    shutdown: -> [@nmc, @dns, @http].forEach (s) -> s?.shutdown?()

