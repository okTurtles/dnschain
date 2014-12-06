#!/usr/bin/env coffee

express = require 'express'
https = require 'https'
http = require 'http'
bodyParser = require 'body-parser'
fs = require 'fs'
path = require 'path'
nconf = require 'nconf'
mkdirp = require 'mkdirp'
ini = require 'ini'

module.exports = (dnschain) ->
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class AdminServer
        constructor: (@dnschain) ->
            @dc = @dnschain
            @globalConf = nconf.stores.global.file
            @userConf = nconf.stores.user.file

            @log = gNewLogger 'Admin'
            @log.debug "Loading AdminServer..."
            @app = express()
            @app.use bodyParser.json()
            # Uses two static directories to serve files with preference to public
            # Ex: if app.js is not found on public, it would serve it from dist instead
            @app.use express.static(__dirname + '/public')
            @app.use express.static(path.join(__dirname + '/../../../dist'))

            httpsOptions =
                key: fs.readFileSync(gConf.get('https:key')),
                cert: fs.readFileSync(gConf.get('https:cert'))

            @httpServer = http.createServer(@app).listen(3000, =>
                @log.info 'started Admin on http://%s:%s', @httpServer.address().address, @httpServer.address().port
            )

            @httpsServer = https.createServer(httpsOptions, @app).listen(4333, =>
                @log.info 'started Admin on https://%s:%s', @httpsServer.address().address, @httpsServer.address().port
            )

            @addRoutes()

        addRoutes: ->
            @app.get '/', (req, res) =>
                res.sendFile __dirname + '/public/views/index.html'
                return

            @app.get '/config', (req, res) =>
                c = config: {}, path: null

                for key of nconf.stores.defaults.store
                    # `type` key is a property of nconf
                    if key isnt 'type'
                        c.config[key] = gConf.get key

                # get path of conf with priority for user-based confs
                if fs.existsSync @userConf
                    c.path = @userConf
                else if fs.existsSync @globalConf
                    c.path = @globalConf

                c.constants = gConsts

                res.json c
                return

            @app.post '/save/config', (req, res) =>
                conf = @globalConf

                # If user conf exists or no conf is created yet
                if fs.existsSync @userConf or ( not fs.existsSync conf and not fs.existsSync @userConf )
                    conf = @userConf

                # Creates a directory if it does not exist
                mkdirp path.dirname(conf), (err) =>
                    if err?
                        res.send
                            msg: conf
                            err: "Could not write to #{path.dirname(conf)}. Please make sure that this directory is writable by the user that DNSChain is running as."
                    else
                        # using ini to stringify, as properties module does not support auto stringification.
                        # Ex: https://github.com/gagle/node-properties/blob/master/examples/ini/stringify-ini.js
                        fs.writeFile conf, ini.stringify(req.body) , (err) =>
                            if err?
                                res.send
                                    msg: conf
                                    err: "Could not write to #{conf}. Please make sure that this file is writable by the user that DNSChain is running as."
                            else
                                # 99: exit code to be sent to grunt to handle restart of servers
                                setImmediate -> process.exit 99
                                @dc.shutdown()
                                res.send msg: conf
                return

        shutdown: ->
            @log.debug 'shutting down!'
            @httpsServer.close()
            @httpServer.close()
