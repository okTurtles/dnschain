###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

module.exports = (dnschain) ->

    # 1. global dependencies

    dnschain.globals =
        rpc    : 'json-rpc2'
        _      : 'lodash-contrib'
        S      : 'string'
        dns2   : 'native-dns'
        es     : 'event-stream'
        sa     : 'stream-array'

    # no renaming done for these
    for d in ['net', 'dns', 'http', 'url', 'util', 'os', 'path', 'winston']
        dnschain.globals[d] = d

    # replace all the string values in dnschain.globals with the module they represent
    # and expose them into this function's namespace
    for k,v of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k} = require('#{v}');"

    # 2. global constants
    _.assign dnschain.globals, consts:
        # for questions that the blockchain cannot answer
        # (hopefully these will disappear with time)
        oldDNS:
            # USE THIS METHOD!
            NATIVE_DNS: 0 # Use 'native-dns' module (current default). Hopefully merged into NodeJS in the future: https://github.com/joyent/node/issues/6864#issuecomment-32229852

            # !! WARNING !!
            # > USING 'NODE_DNS' IS __STRONGLY DISCOURAGED!__   <
            # > BECAUSE IT DOES NOT PROVIDE PROVIDE TTL VALUES! <
            # !! WARNING !!
            NODE_DNS: 1 # Prior to node 0.11.x will ignore dnsOpts.oldDNS and use OS-specified DNS. Currently ignores 'dnsOpts.oldDNS' in favor of OS-specified DNS even in node 0.11.x (simply needs to be implemented). TODO: <- this!
    
    # 3. create global functions, and then return the entire globals object
    _.assign dnschain.globals, {
        externalIP: do ->
            cachedIP = null
            faces = os.networkInterfaces()
            default_iface = switch
                when os.type() is 'Darwin' and faces.en0? then 'en0'
                when os.type() is 'Linux' and faces.eth0? then 'eth0'
                else _(faces).keys().find (x)-> !x.match /lo/
            (iface=default_iface, cached=true,fam='IPv4',internal=false) ->
                cachedIP = switch
                    when cached and cachedIP then cachedIP
                    else
                        unless ips = (faces = os.networkInterfaces())[iface]
                            throw new Error util.format("No such interface '%s'. Available: %j", iface, faces)
                        _.find(ips, {family:fam, internal:internal}).address
        
        newLogger: (name) ->
            new winston.Logger
                levels: winston.config.cli.levels
                colors: winston.config.cli.lcolors
                transports: [
                    new winston.transports.Console
                        label:name
                        level: config.get 'log:level'
                        colorize: config.get 'log:cli'
                        prettyPrint: config.get 'log:pretty'
                        timestamp: config.get 'log:timestamp'
                ]

        tErr: (args...) ->
            e = new Error util.format args...
            gLogger.error e.stack
            throw e

        # TODO: this function should take one parameter: an IP string
        #       and return either 'A' or 'AAAA'
        #       A separate function called type2rec should do what the inner fn does
        ip2type: (d, ttl, type='A') ->
            (ip)-> dns2[type] {name:d, address:ip, ttl:ttl}

        # Currently this function is namecoin-specific.
        # DANE/TLSA info: https://tools.ietf.org/html/rfc6698
        # TODO: implement RRSIG from http://tools.ietf.org/html/rfc4034
        #       as in: dig @8.8.4.4 +dnssec TLSA _443._tcp.good.dane.verisignlabs.com
        tls2tlsa: (tls, ttl, queryname) ->
            [port, protocol] = (queryname.split '.')[0..1].map (o)-> o.replace '_',''
            if !tls?[protocol]?[port]?
                return []
            tls[protocol][port].map (certinfo) ->
                dns2.TLSA
                    name: queryname
                    ttl: ttl
                    usage: 3     # 3 = "Fuck CAs."
                    selector: 1  # SubjectPublicKeyInfo: DER-encoded [RFC5280]
                    matchingtype: certinfo[0]
                    buff: new Buffer certinfo[1], 'hex'
    }

    # 4. vars for use within the map above and elsewhere
    config = dnschain.globals.config = require('./config')(dnschain)
    gLogger = dnschain.globals.gLogger = dnschain.globals.newLogger 'Global Logger'

    # 5. return the globals object
    dnschain.globals
