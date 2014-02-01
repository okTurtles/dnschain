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

    # TODO: add path to our private key for signing answers

    dnscDefs =
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

    nmcDefs =
        rpcport: 8336
        rpcconnect: '127.0.0.1'
        rpcuser: undefined
        rpcpassword: undefined

    fileFormatOpts =
        comments: ['#', ';']
        sections: true

    props.parse = _.partialRight props.parse, fileFormatOpts
    props.stringify = _.partialRight props.stringify, fileFormatOpts
    

    # load our config
    appname = "dnschain"
    nconf.argv().env()

    if process.env.HOME?
        dnscConf = path.join process.env.HOME, ".#{appname}.conf"
        unless fs.existsSync dnscConf
            dnscConf = path.join process.env.HOME, ".#{appname}", "#{appname}.conf"
        nconf.file 'user', {file: dnscConf, format: props}

    nconf.file 'global', {file:"/etc/#{appname}/#{appname}.conf", format:props}

    # namecoin
    nmc = (new nconf.Provider()).argv().env()
    
    nmcConf = if process.env.APPDATA?
        path.join process.env.APPDATA, "Namecoin", "namecoin.conf"
    else if process.env.HOME?
        path.join process.env.HOME, ".namecoin", "namecoin.conf"

    nmc.file('user', {file:nmcConf,format:props}) if nmcConf

    stores =
        dnschain: nconf.defaults dnscDefs
        nmc: nmc.defaults nmcDefs

    config =
        get: (key, store="dnschain") -> stores[store].get key
        set: (key, value, store="dnschain") -> stores[store].set key, value
        # Namecoin's config is not ours, so we don't pretend it is
        nmc:
            get: (key)-> config.get key, 'nmc'
            set: (key, value)-> config.set key, value, 'nmc'