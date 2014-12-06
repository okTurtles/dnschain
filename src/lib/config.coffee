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
        https:
            port: 443
            host: '0.0.0.0'
            internalTLSPort: 15001
            key: "./key.pem"
            cert: "./cert.pem"
        http:
            port: if amRoot then 80 else 8088
            tlsPort: if amRoot then 443 else 4443
            host: '0.0.0.0' # what we bind to

    nmcDefs =
        rpcport: 8336
        rpcconnect: '127.0.0.1'
        rpcuser: undefined
        rpcpassword: undefined

    bdnsDefs =
        rpc:
            rpc_user: undefined
            rpc_password: undefined
            httpd_endpoint: undefined
    
    fileFormatOpts =
        comments: ['#', ';']
        sections: true
        namespaces: true

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

    # TODO: this blockchain-specific config stuff should be moved out of
    #       this file and into the constructors (NMCPeer, BDNSPeer, etc.)

    # namecoin
    nmc = (new nconf.Provider()).argv().env()
    
    # TODO: use the same _.find technique as done below for bdnsConf
    nmcConf = if process.env.APPDATA?
        path.join process.env.APPDATA, "Namecoin", "namecoin.conf"
    else if process.env.HOME?
        path.join process.env.HOME, ".namecoin", "namecoin.conf"

    nmc.file('user', {file:nmcConf,format:props}) if nmcConf

    # bdns
    bdns = (new nconf.Provider()).argv().env()
    bdnsConf = _.find _.filter([
        [process.env.APPDATA, "KeyID"],
        [process.env.HOME, ".KeyID"],
        [process.env.HOME, "Library", "Application Support", "KeyID"]]
    , (x) -> !!x[0])
    , (x) -> fs.existsSync path.join x...

    if bdnsConf
        bdns.file 'user', file: path.join(bdnsConf..., 'config.json')
    else
        # TODO: this!

    stores =
        dnschain: nconf.defaults defaults
        nmc: nmc.defaults nmcDefs
        bdns: bdns.defaults bdnsDefs

    config =
        get: (key, store="dnschain") -> stores[store].get key
        set: (key, value, store="dnschain") -> stores[store].set key, value
        # Namecoin's config is not ours, so we don't pretend it is
        nmc:
            get: (key)-> config.get key, 'nmc'
            set: (key, value)-> config.set key, value, 'nmc'
        bdns:
            get: (key)-> config.get key, 'bdns'
            set: (key, value)-> config.set key, value, 'bdns'
