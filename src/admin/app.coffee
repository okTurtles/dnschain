#!/usr/bin/env coffee

express = require 'express'
https = require 'https'
http = require 'http'
bodyParser = require 'body-parser'
fs = require 'fs'
path = require 'path'
nconf = require 'nconf'
mkdirp = require 'mkdirp'
props = require 'properties'

module.exports = (dnschain) ->
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    class AdminServer
        constructor: (@dnschain) ->
            @globalConf = nconf.stores.global.file
            @userConf = (if nconf.stores.user then nconf.stores.user.file else null)

            @log = gNewLogger 'Admin'
            @log.debug "Loading AdminServer..."
            @app = express()
            @app.use bodyParser.json()

            # Uses three static directories to serve files in the order specified below, first being /public
            # Added /public/js to maintain path compatibility with dist, ie, for app.js
            @app.use express.static(__dirname + '/public')
            @app.use express.static(__dirname + '/public/js')
            @app.use express.static(path.join(__dirname + '../../../dist'))

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
                if !!@userConf and (fs.existsSync(@userConf) or (not fs.existsSync(conf) and not fs.existsSync(@userConf)))
                    conf = @userConf

                # Creates a directory if it does not exist
                mkdirp path.dirname(conf), (err) =>
                    if err?
                        res.send
                            msg: conf
                            err: "Could not write to #{path.dirname(conf)}.\nPlease make sure that this directory is writable by the user that DNSChain is running as."
                    else
                        stringifier = props.createStringifier()
                        createSection = (k, v) ->
                            stringifier.section(k)
                            if typeof v is 'object'
                                for pk, pv of v
                                    if typeof pv is 'object'
                                        createSection "#{k}.#{pk}", pv
                                    else
                                        stringifier.property key: pk, value: pv

                        for k,v of req.body
                            createSection k, v

                        fs.writeFile conf, props.stringify(stringifier), (err) =>
                            if err?
                                res.send
                                    msg: conf
                                    err: "Could not write to #{conf}.\nPlease make sure that this file is writable by the user that DNSChain is running as."
                            else
                                # 99: exit code to be sent to grunt to handle restart of servers
                                @dnschain.shutdown()
                                setTimeout (->
                                    process.exit 99
                                ), 500
                                res.send msg: conf
                return

        shutdown: ->
            @log.debug 'shutting down!'
            @httpsServer.close()
            @httpServer.close()
