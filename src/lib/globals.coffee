###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

module.exports = (dnsnmc) ->

    # 1. global dependencies

    dnsnmc.globals =
        rpc    : 'json-rpc2'
        _      : 'lodash-contrib'
        S      : 'string'
        dns2   : 'native-dns'
        es     : 'event-stream'
        sa     : 'stream-array'

    # no renaming done for these
    ['net', 'dns', 'http', 'url', 'util', 'os', 'path', 'winston'].forEach (d) ->
        dnsnmc.globals[d] = d

    # replace all the string values in dnsnmc.globals with the module they represent
    # and expose them into this function's namespace
    for k,v of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k} = require('#{v}');"

    # 2. global constants
    _.assign dnsnmc.globals, consts:
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
    
    # 3. config
    config = dnsnmc.globals.config = require('./config')(dnsnmc)

    # 4. create global functions, and then return the entire globals object
    _.assign dnsnmc.globals, {
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
            msg = util.format args...
            e = new Error msg
            @log?.error e.stack
            throw e

        
        ip2type: (d, ttl, type='A') ->
            (ip)-> dns2[type] {name:d, address:ip, ttl:ttl}
    }