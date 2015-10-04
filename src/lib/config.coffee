###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

###
All configuration options can be overwritten using command line args
and/or environment variables.

Below you will see the available options and their defaults.

- The top-level options map to sections in the config file.
  I.e. `dns` and `log` designate the sections `[dns]` and `[log]`
- All non top-level options are respresented via dot notation.
  I.e. to set the `oldDNS` `address`, you'd do:

    [dns]
    oldDNS.address = 8.8.4.4

- For each blockchain, you can specify its configuration file
  by specifying the blockchain name as a section, and then
  setting the config variable.
  Example:

    [namecoin]
    config = /home/namecoin/.namecoin/namecoin.conf

See also:
<https://github.com/okTurtles/dnschain/blob/master/docs/How-do-I-run-my-own.md#Configuration>
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

    # =================================================
    # BEGIN DNSCHAIN CONFIGURATION OPTIONS AND DEFAULTS
    # =================================================
    defaults = {
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
            cors: false
        redis:
            socket: '127.0.0.1:6379' # or UNIX domain socket path
            oldDNS:
                enabled: false
                ttl: 600 # Maximum time to keep DNS records in cache, regardless of TTL
            blockchain:
                enabled: false
                ttl: 600

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
    }
    # ===============================================
    # END DNSCHAIN CONFIGURATION OPTIONS AND DEFAULTS
    # ===============================================

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
    nconf.argv().env('__')
    dnscConfLocs = [
        "#{process.env.HOME}/.dnschain/dnschain.conf",  # the default
        "#{process.env.HOME}/.dnschain.conf",
        "/etc/dnschain/dnschain.conf"
    ]
    dnscConf = _.find dnscConfLocs, (x) -> fs.existsSync x

    if process.env.HOME and not fs.existsSync "#{process.env.HOME}/.dnschain"
        # create this folder on UNIX based systems so that https.coffee
        # can autogen the private/public key if they don't exist
        fs.mkdirSync "#{process.env.HOME}/.dnschain", 0o710

    # we can't access `dnschain.globals.gLogger` here because it hasn't
    # been defined yet unfortunately.
    if dnscConf
        console.info "[INFO] Loading DNSChain config from: #{dnscConf}"
        nconf.file 'user', {file: dnscConf, format: props}
    else
        console.warn "[WARN] No DNSChain configuration file found. Using defaults!".bold.yellow
        nconf.file 'user', {file: dnscConfLocs[0], format: props}

    config =
        get: (key, store="dnschain") -> config.chains[store].get key
        set: (key, value, store="dnschain") -> config.chains[store].set key, value
        chains:
            dnschain: nconf.defaults defaults
        add: (name, paths, type) ->
            log = dnschain.globals.gLogger
            gLineInfo = dnschain.globals.gLineInfo
            if config.chains[name]?
                log.warn gLineInfo "Not overwriting existing #{name} configuration"
                return config.chains[name]

            paths = [paths] unless Array.isArray(paths)
            type = confTypes[type] || confTypes['JSON']

            # if dnschain's config specifies this chain's config path, prioritize it
            # fixes: https://github.com/okTurtles/dnschain/issues/60
            customConfigPath = config.chains.dnschain.get "#{name}:config"
            if customConfigPath?
                paths = [customConfigPath]
                log.info "custom config path for #{name}: #{paths[0]}"

            confFile = _.find paths, (x) -> fs.existsSync x

            unless confFile
                log.warn "Couldn't find #{name} configuration:".bold.yellow, paths
                return

            conf = (new nconf.Provider()).argv().env()
            log.info "#{name} configuration path: #{confFile}"
            conf.file 'user', {file: confFile, format: type}
            # if dnschain's config specifies this chain's config information, use it as default
            if config.chains.dnschain.get("#{name}")?
                conf.defaults config.chains.dnschain.get "#{name}"
            config.chains[name] = conf
