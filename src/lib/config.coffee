###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

# TODO: go through 'TODO's!

###
- DNSChain configuration:
    - local in ~/.dnschain.conf (or ~/.dnschain/dnschain.conf)
    - global in /etc/dnschain/dnschain.conf
- Namecoin
    - Non-Windows: ~/.namecoin/namecoin.conf
    - Windows: %APPDATA%\Namecoin\namecoin.conf

All parametrs can be overwritten using command line args and/or environment variables.
###

nconf = require 'nconf'
props = require 'properties'
fs = require 'fs'
tty = require 'tty'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    # TODO: add path to our private key for signing answers
    amRoot = process.getuid() is 0

    defaults =
        log:
            level: if process.env.DNS_EXAMPLE then 'debug' else 'info'
            colors: true
            pretty: tty.isatty process.stdout
            timestamp: tty.isatty process.stdout
        dns:
            port: if amRoot then 53 else 5333
            host: '0.0.0.0' # what we bind to
            externalIP: gExternalIP() # Advertised IP for .dns metaTLD (ex: namecoin.dns)
            oldDNSMethod: 'NATIVE_DNS' # see 'globals.coffee' for possible values
            oldDNS:
                address: '8.8.8.8' # Google (we recommend running PowerDNS yourself and sending it there)
                port: 53
                type: 'udp'
        http:
            port: if amRoot then 80 else 8088       # Standard HTTP port
            tlsPort: if amRoot then 443 else 4443   # Standard HTTPS port
            tlsKey: "#{process.env.HOME}/.dnschain/key.pem"
            tlsCert: "#{process.env.HOME}/.dnschain/cert.pem"
            internalTLSPort: 2500   # Not accessible from the internet, used internally only
            internalAdminPort: 3000 # Not accessible from the internet, used internally only
            host: '0.0.0.0' # what we bind to. 0.0.0.0 for the whole internet
        redis:
            enabled: false
            host: '127.0.0.1'
            port: 6379

        unblock: # The options in this section are only for when Unblock is enabled.
            enabled: false
            acceptApiCallsTo: ["localhost"] # Add your public facing domain here if you want to accept calls to the RESTful API when Unblock is enabled.
            routeDomains: { # If traffic coming in on the tlsPort needs to be redirected to another application on the server then add it here
                # Example: "mywebsite.com" : 9000  # This tells the server to send traffic meant to "mywebsite.com" to port 9000. It'll still be encrypted when it reaches port 9000
            }

        # WARNING: Do not change these settings unless you know exactly what you're doing.
        # Read the source code, read the Bottleneck docs,
        # make sure you understand how it might make your server complicit in DNS Amplification Attacks and your server might be taken down as a result.
        rateLimiting:
            dns:
                maxConcurrent: 1
                minTime: 200
                highWater: 2
                strategy: Bottleneck.strategy.BLOCK
                penalty: 7000
            http:
                maxConcurrent: 2
                minTime: 150
                highWater: 10
                strategy: Bottleneck.strategy.OVERFLOW
            https:
                maxConcurrent: 2
                minTime: 150
                highWater: 10
                strategy: Bottleneck.strategy.OVERFLOW


    fileFormatOpts =
        comments: ['#', ';']
        sections: true
        namespaces: true

    props.parse = _.partialRight props.parse, fileFormatOpts
    props.stringify = _.partialRight props.stringify, fileFormatOpts

    confTypes =
        INI: props
        JSON: JSON

    # load our config
    appname = "dnschain"
    nconf.argv().env()

    if process.env.HOME?
        dnscConf = path.join process.env.HOME, ".#{appname}.conf"
        unless fs.existsSync dnscConf
            dnscConf = path.join process.env.HOME, ".#{appname}", "#{appname}.conf"
        nconf.file 'user', {file: dnscConf, format: props}

    nconf.file 'global', {file:"/etc/#{appname}/#{appname}.conf", format:props}

    config =
        get: (key, store="dnschain") -> config.chains[store].get key
        set: (key, value, store="dnschain") -> config.chains[store].set key, value
        chains:
            dnschain: nconf.defaults defaults
        add: (name, path, type) ->
            return if config.chains[name]?
            path = [path] if not Array.isArray(path)
            type = confTypes[type] || confTypes['JSON']

            # if dnschain's config specifies this chain's config path, prioritize it
            # fixes: https://github.com/okTurtles/dnschain/issues/60
            path.push(config.chains.dnschain.get("#{name}:config")) if config.chains.dnschain.get("#{name}:config")?

            conf = (new nconf.Provider()).argv().env()
            confFile = _.find path, (x) -> fs.existsSync x
            conf.file('user',{file: confFile, format: type}) if confFile
            # if dnschain's config specifies this chain's config information, use it as default
            conf.defaults(config.chains.dnschain.get("#{name}")) if config.chains.dnschain.get("#{name}")?
            config.chains[name] = conf
