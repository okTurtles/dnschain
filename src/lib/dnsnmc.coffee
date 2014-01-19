###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

'use strict'

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

###

# exports.protected = project-wide static vars and dependencies
renameDeps =
    rpc       : 'json-rpc2'
    _         : 'lodash'
    S         : 'string'
    dns2      : 'native-dns'
    es        : 'event-stream'
    emitStream: 'emit-stream'

for d,dep of renameDeps
   eval "var #{d} = exports.protected.#{d} = require('#{dep}');"

for d in ['net', 'dns', 'http', 'url', 'util']
    eval "var #{d} = exports.protected.#{d} = require('#{d}');"

# mixin fancy functional stuff to latest version of lodash
require 'lodash-contrib'

# `dns`  = nodejs' dns (currently lacks ability to specify dns server for query)
# `dns2` = native-dns (to be merged into nodejs in the future, according to author. used for specifying dns servers per query)
# `dnsd` = well-maintained dns server API. dns2 can also act as server, but dnsd is actively maintained.
#          for now I am holding off on using it for the sake of simplicity (single API), but if
#          we discover a lacking server funcionality in native-dns, we'll switch to it for that purpose.

tErr = exports.protected.tErr = (args...)-> throw new Error args...

exports.defaults =
    dnsOpts:
        port: 53
        host: '0.0.0.0'
        fallbackDNS:
            address: '8.8.8.8' # Google (we recommend running PowerDNS yourself and sending it there)
            port: 53
            type: 'udp'
    httpOpts:
        port: 80
        tlsPort: 443
        host: '127.0.0.1'
    rpcOpts:
        port: 8336
        host: '127.0.0.1'

exports.createServer = (a...)->
    new DNSNMC a...

exports.DNSNMC = class DNSNMC
    # TODO: read in configuration files!

    constructor: (@rpcOpts, @dnsOpts={}, @httpOpts={})->
        @log = require('bunyan').createLogger
            name:"dnsnmc#{DNSNMC::count = (DNSNMC::count ? -1) + 1}"
            streams: [{stream: process.stderr, level: 'debug'}]

        for k in [ "rpcOpts", "dnsOpts", "httpOpts" ]
            @[k] = _.merge _.cloneDeep(exports.defaults[k]), @[k]

        try
            @nmc = new NMCPeer @
            @dns = new DNSServer @
            @http = new HTTPServer @            
        catch e
            service.shutdown() for service in [@nmc, @dns, @http]
            @log.error "dnsnmc failed to start: %s", e
            throw e # rethrow

NMCPeer = require('./nmc')(exports)
DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)