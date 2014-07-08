###

dnschain
http://dnschain.org

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->

    # 1. global dependencies
    #
    # IMPORTANT: *ALL* DNSChain globals *MUST* be prefixed with a 'g'
    #            *EXCEPT* the global module dependencies below.

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
    _.assign dnschain.globals, gConsts:
        # for questions that the blockchain cannot answer (hopefully these will disappear with time)
        # >> Use the keys (as string values) in your config!   <<
        # >> Do *NOT* use the numerical values in your config! <<
        # For now they're supported but their use is DEPRECATED and they *WILL* be removed!
        oldDNS:
            # Recommended method
            NATIVE_DNS: 0 # Use 'native-dns' module (current default). Hopefully merged into NodeJS in the future: https://github.com/joyent/node/issues/6864#issuecomment-32229852

            #                    !! WARNING !!
            # > ! USING 'NODE_DNS' IS __STRONGLY DISCOURAGED__   ! <
            # > ! BECAUSE IT DOES NOT PROVIDE PROVIDE TTL VALUES ! <
            # > ! ITS USE MAY BE DEPRECATED IN THE FUTURE        ! <
            NODE_DNS: 1 # Prior to node 0.11.x will ignore dnsOpts.oldDNS and use OS-specified DNS. Currently ignores 'dnsOpts.oldDNS' in favor of OS-specified DNS even in node 0.11.x (simply needs to be implemented). TODO: <- this!

            # Refuse to resolve domains in the canonical DNS system
            # unless the blockchain tells us to, in which case the
            # NATIVE_DNS method will be used for that purpose.
            NO_OLD_DNS: 2

            # Never resolve domains in canonical DNS. Return REFUSED for all such requests.
            NO_OLD_DNS_EVER: 3

    # 3. create global functions, and then return the entire globals object
    _.assign dnschain.globals, {
        gExternalIP: do ->
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

        gNewLogger: (name) ->
            new winston.Logger
                levels: winston.config.cli.levels
                colors: winston.config.cli.lcolors
                transports: [
                    new winston.transports.Console
                        label:name
                        level: gConf.get 'log:level'
                        colorize: gConf.get 'log:colors'
                        prettyPrint: gConf.get 'log:pretty'
                        timestamp: gConf.get 'log:timestamp'
                ]

        gErr: (args...) ->
            e = new Error util.format args...
            gLogger.error e.stack
            throw e

        # TODO: this function should take one parameter: an IP string
        #       and return either 'A' or 'AAAA'
        #       A separate function called type2rec should do what the inner fn does
        #       https://github.com/okTurtles/dnschain/issues/7
        gIP2type: (d, ttl, type='A') ->
            (ip)-> dns2[type] {name:d, address:ip, ttl:ttl}

        # Currently this function is namecoin-specific.
        # DANE/TLSA info: https://tools.ietf.org/html/rfc6698
        # TODO: implement RRSIG from http://tools.ietf.org/html/rfc4034
        #       as in: dig @8.8.4.4 +dnssec TLSA _443._tcp.good.dane.verisignlabs.com
        gTls2tlsa: (tls, ttl, queryname) ->
            [port, protocol] = (queryname.split '.')[0..1].map (o)-> o.replace '_',''
            if !tls?[protocol]?[port]?
                return []
            tls[protocol][port].map (certinfo) ->
                dns2.TLSA
                    name: queryname
                    ttl: ttl
                    usage: 3     # 3 = "Fuck CAs" :P
                    selector: 1  # SubjectPublicKeyInfo: DER-encoded [RFC5280]
                    matchingtype: certinfo[0]
                    buff: new Buffer certinfo[1], 'hex'

        gLineInfo: (prefix='') ->
            stack = new Error().stack
            # console.log stack.split('\n')[2]
            [file, line] = stack.split('\n')[2].split ':'
            [func, file] = file.split ' ('
            [func, file] = ['??', func] unless file # sometimes the function isn't specified
            [func, file] = [func.split(' ').pop(), path.basename(file)]
            [junk, func] = func.split('.')
            func = junk unless func
            func = if func is '??' or func is '<anonymous>' then ' (' else " (<#{func}> "
            prefix + func + file + ':' + line + ')'
    }

    # 4. vars for use within the map above and elsewhere
    gConf = dnschain.globals.gConf = require('./config')(dnschain)
    gLogger = dnschain.globals.gLogger = dnschain.globals.gNewLogger 'Global'
    gConsts = dnschain.globals.gConsts

    # handle DEPRECATED numerical oldDNSMethod values
    method = gConf.get 'dns:oldDNSMethod'
    if typeof method isnt 'string'
        method = _.keys(_.pick gConsts.oldDNS, (v,k)-> v is method)[0]
        gLogger.warn "Specifying 'oldDNSMethod' as a number is DEPRECATED!".bold.red
        gLogger.warn "Please specify the string value instead:".bold.red, "#{method}".bold
    else
        if (method_num = gConsts.oldDNS[method])?
            # kinda hackish... but makes for easy and quick comparisons
            gConf.set 'dns:oldDNSMethod', method_num
        else
            gLogger.error "No such oldDNS method:".bold.red, method.bold
            process.exit 1


    # 5 Import the Unblock.us configuration
    unblockSettings = require "./unblock/settings"
    dnsSettings = gConf.get "dns"

    unblockSettings.IPv4 = dnsSettings.externalIP
    # TODO: Add IPv6 support... cmon it's 2014 already! And TCP too! And TCP Ipv6!
    unblockSettings.forwardDNS = dnsSettings.oldDNS.address
    unblockSettings.forwardDNSPort = dnsSettings.oldDNS.port

    dnschain.globals.unblockSettings = unblockSettings


    # 6. return the globals object
    dnschain.globals
