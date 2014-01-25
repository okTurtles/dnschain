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

###

# exports.globals = project-wide static vars and dependencies
renameDeps =
    rpc : 'json-rpc2'
    _   : 'lodash-contrib'
    S   : 'string'
    dns2: 'native-dns'
    es  : 'event-stream'
    sa  : 'stream-array'

exports.globals = {}

for d,dep of renameDeps
    eval "var #{d} = exports.globals.#{d} = require('#{dep}');"

for d in ['net', 'dns', 'http', 'url', 'util', 'os', 'winston']
    eval "var #{d} = exports.globals.#{d} = require('#{d}');"

# `dns`  = nodejs' dns (currently lacks ability to specify dns server for query)
# `dns2` = native-dns (to be merged into nodejs in the future, according to author. used for specifying dns servers per query)
# `dnsd` = well-maintained dns server API. dns2 can also act as server, but dnsd is actively maintained.
#          for now I am holding off on using it for the sake of simplicity (single API), but if
#          we discover a lacking server funcionality in native-dns, we'll switch to it for that purpose.

tErr = exports.globals.tErr = (args...)-> throw new Error args...

exports.globals.ip2type = (domain, ttl, type='A') ->
    (ip)-> dns2[type]({name:domain, address:ip, ttl:ttl})

# TODO: get 'iface' from 'config'!
externalIP = exports.externalIP = exports.globals.externalIP = do ->
    faces = os.networkInterfaces()
    default_iface = switch
        when os.type() is 'Darwin' and faces.en0? then 'en0'
        when os.type() is 'Linux' and faces.eth0? then 'eth0'
        else _(faces).keys().find (x)-> !x.match /lo/
    cachedIP = undefined

    # TODO: TO DEFER RESOLUTION USE NODE'S DNS FUNCTIONS! NOT DNS2!! BETTER YET, MAKE IT OPTIONAL TO USE DNS2!
    # cachedIP = '127.0.0.1'

    (iface=default_iface, cached=true,fam='IPv4',internal=false) ->
        if cached and cachedIP
            cachedIP
        else
            faces = os.networkInterfaces()
            unless ip = faces[iface]
                throw new Error util.format("No such interface '%s'. Available: %j", iface, faces)
            cachedIP = _.find(ip, {family:fam, internal:internal}).address


consts = exports.consts = exports.globals.consts =
    # for questions that the blockchain cannot answer
    # (hopefully these will disappear with time)
    oldDNS:
        nativeDNSModule: 0 # Use 'native-dns' module (current default). Hopefully merged into NodeJS in the future: https://github.com/joyent/node/issues/6864#issuecomment-32229852
        nodeDNSModule: 1 # Prior to node 0.11.x will ignore dnsOpts.oldDNS and use OS-specified DNS. Currently ignores 'dnsOpts.oldDNS' in favor of OS-specified DNS even in node 0.11.x (simply needs to be implemented). TODO: <- this!


exports.defaults =
    dnsOpts:
        port: 53
        host: '0.0.0.0'
        oldDNSMethod: consts.oldDNS.nativeDNSModule
        # oldDNSMethod: consts.oldDNS.nodeDNSModule
        oldDNS:
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
        @log = @newLogger 'DNSNMC'

        for k,v of _.pick(exports.defaults, ['rpcOpts', 'dnsOpts', 'httpOpts'])
            _.defaults @[k], v

        try
            @nmc = new NMCPeer @
            @dns = new DNSServer @
            @http = new HTTPServer @
            @log.info "DNSNMC running with external IP: ", externalIP()
        catch e
            @log.error "dnsnmc failed to start", {exception: e}
            @shutdown()
            throw e # rethrow

    newLogger: (name, level='debug') ->
        logger = new winston.Logger
            levels: winston.config.cli.levels
            colors: winston.config.cli.lcolors
            transports: [
                new winston.transports.Console
                    label:name
                    level:level
                    colorize:true
                    prettyPrint:true
                    timestamp:true
            ]
        # logger.cli()

    shutdown: -> [@nmc, @dns, @http].forEach (s) -> s?.shutdown?()

NMCPeer = require('./nmc')(exports)
DNSServer = require('./dns')(exports)
HTTPServer = require('./http')(exports)