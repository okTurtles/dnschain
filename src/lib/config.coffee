###

dnschain
http://dnschain.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# TODO: go through 'TODO's!

###
- configuration:
    - local in ~/.dnschain
    - global in /etc/dnschain
    - support command line providing configuration (overrides both of the above)
    - options:
        - everything in exports.defaults
        - logging options for bunyan
###

nconf = require 'nconf'
props = require 'properties'
fs = require 'fs'
tty = require 'tty'

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    dnschainDefaults =
        log:
            level: 'debug'
            cli: tty.isatty process.stdout
            pretty: tty.isatty process.stdout
            timestamp: true
        dns:
            port: 53
            host: '0.0.0.0'
            oldDNSMethod: consts.oldDNS.NATIVE_DNS # Use NATIVE_DNS until node gives TTLs!
            oldDNS:
                address: '8.8.8.8' # Google (we recommend running PowerDNS yourself and sending it there)
                port: 53
                type: 'udp'
        http:
            port: 80
            tlsPort: 443
            host: '0.0.0.0'

    nmcDefaults =
        rpcport: 8336
        rpcconnect: '127.0.0.1'
        rpcuser: undefined
        rpcpassword: undefined

    fileFormatOpts =
        comments: ['#', ';']
        sections: true

    props.parse = _.partialRight props.parse, fileFormatOpts
    props.stringify = _.partialRight props.stringify, fileFormatOpts
    
    appname = "dnschain"
    dnschain = nconf.argv().env()
    nmc = new nconf.Provider()

    if process.env.APPDATA?
        nmc.file(
            file: path.join(process.env.APPDATA, "Namecoin/namecoin.conf")
            format: props
        )

    if process.env.HOME?
        dnschain.file(file: path.join(process.env.HOME, ".#{appname}/#{appname}.conf"))
            .file(file: path.join(process.env.HOME, ".#{appname}.conf"))
        # namecoin
        nmc.file(
            file: path.join(process.env.HOME, ".namecoin/namecoin.conf")
            format: props
        ).file(
            file: path.join(process.env.HOME, "Library/Application Support/Namecoin/namecoin.conf")
            format: props
        )
    
    dnschain.file file:"/etc/#{appname}/#{appname}.conf"

    stores =
        dnschain: dnschain.defaults dnschainDefaults
        nmc: nmc.defaults nmcDefaults

    config =
        get: (key, store="dnschain") -> stores[store].get key
        set: (key, value, store="dnschain") -> stores[store].set key, value
        # Namecoin's config is not ours, so we don't pretend it is
        nmc:
            get: (key)-> config.get key, 'nmc'
            set: (key, value)-> config.set key, value, 'nmc'