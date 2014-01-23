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


security:

- protect against DDoS DNS amplification attacks. 

###

# exports.globals = project-wide static vars and dependencies
renameDeps =
    rpc : 'json-rpc2'
    _   : 'lodash-contrib'
    S   : 'string'
    dns2: 'native-dns'
    es  : 'event-stream'
    sa  : 'stream-array'

for d,dep of renameDeps
    eval "var #{d} = exports.globals.#{d} = require('#{dep}');"

for d in ['net', 'dns', 'http', 'url', 'util', 'os']
    eval "var #{d} = exports.globals.#{d} = require('#{d}');"

# `dns`  = nodejs' dns (currently lacks ability to specify dns server for query)
# `dns2` = native-dns (to be merged into nodejs in the future, according to author. used for specifying dns servers per query)
# `dnsd` = well-maintained dns server API. dns2 can also act as server, but dnsd is actively maintained.
#          for now I am holding off on using it for the sake of simplicity (single API), but if
#          we discover a lacking server funcionality in native-dns, we'll switch to it for that purpose.

tErr = exports.globals.tErr = (args...)-> throw new Error args...

exports.globals.ip2type = (domain, ttl, type='A') ->
    (ip)-> dns2[type] {name:domain, address:ip, ttl:ttl}


# TODO: get this from 'config'!
externalIP = exports.globals.externalIP = do ->
    faces = os.networkInterfaces()
    default_iface = switch
        when os.type() is 'Darwin' then 'en0'
        when os.type() is 'Linux' then 'eth0'
        else _(faces).keys().reject((x)->x.match /lo/).first()
    cachedIP = undefined

    (iface=default_iface, cached=true,fam='IPv4',internal=false) ->
        if cached and cachedIP
            cachedIP
        else
            faces = os.networkInterfaces()
            unless ip = faces[iface]
                throw new Error util.format("No such interface '%s'. Available: %j", iface, faces)
            cachedIP = ip.filter({family:fam, internal:internal})[0].address

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

        _.defaults @, _.pick(exports.defaults, ['rpcOpts', 'dnsOpts', 'httpOpts'])

        try
            @nmc = new NMCPeer @
            @dns = new DNSServer @
            @http = new HTTPServer @
            @log.info "DNSNMC running with external IP: %s", externalIP()
        catch e
            @shutdown()
            @log.error "dnsnmc failed to start: %s", e
            throw e # rethrow

    shutdown: -> [@nmc, @dns, @http].forEach (s) -> s.shutdown()

NMCPeer = require('./nmc')(exports)
DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)