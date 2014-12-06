###

dnschain
http://dnschain.net

Copyright (c) 2014 okTurtles Foundation

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (grunt)->
    # load all grunt tasks
    require('matchdep').filterDev('grunt-*').forEach grunt.loadNpmTasks

    _ = grunt.util._
    path = require 'path'
    util = require 'util'
    child_process = require 'child_process'

    # Project configuration.
    grunt.initConfig
        pkg: grunt.file.readJSON 'package.json'
        example: './src/example/example.coffee'
        admin: './src/admin'
        dist: './dist'

        coffeelint:
            gruntfile: ['<%= watch.gruntfile.files %>']
            src: ['<%= watch.src.files %>']
            options:
                configFile: "coffeelint.json"


        # Ref: Using browserify. Had issue with coffeeify with error: cannot find 'through' module.
        browserify:
            app:
                files:
                    '<%= admin %>/public/js/app.js': ['<%= admin %>/public/coffee/index.coffee']
                options:
                    browserifyOptions:
                        debug: true
                    transform: ['coffee-reactify']
            dist:
                files:
                    '<%= dist %>/js/app.js': ['<%= admin %>/public/coffee/index.coffee']
                options:
                    transform: ['coffee-reactify']

        watch:
            options:
                spawn: true
                debounceDelay: 100
            gruntfile:
                files: 'Gruntfile.coffee'
                tasks: ['coffeelint:gruntfile']
            src:
                # restart server for only server-side code change
                files: ['src/lib/*.coffee','src/example/*.coffee', '<%= admin %>/app.coffee']
                tasks: ['coffeelint:src', 'example:respawn']
            web:
                files: ['<%= admin %>/public/**/*.coffee', 'src/**/*.cjsx'],
                tasks: ['coffeelint:src', 'browserify:app']


    grunt.event.on 'watch', (action, files, target)->
        grunt.log.writeln "#{target}: #{files} has #{action}"
        grunt.config ['coffeelint', target], src: files

    # tasks.
    grunt.registerTask 'default', ['example']

    # generate app.js on dist directory.
    grunt.registerTask 'dist', ['browserify:dist']

    grunt.registerTask 'example', 'Run Example', ->
        # prevent watch from spawning. if we don't do this, we won't be able
        # to kill the child when files change.
        grunt.config ['watch', 'options'], spawn: false
        grunt.task.run 'browserify:app', 'example:respawn', 'watch'


    child = running: false

    grunt.registerTask 'example:respawn', '[internal]', ->
        done = @async() # tell grunt we're async

        if child.running
            grunt.log.writeln "Killing child!"
            child.running = false
            child.proc.kill 'SIGINT' # nicer...

        spawn = (child) ->
            grunt.log.writeln "example: spawning child..."
            spawnOpts =
                cwd: process.cwd()
                env: process.env
                stdio: 'inherit'
            child.proc = child_process.spawn grunt.config('example'), process.argv, spawnOpts
            child.running = true
            child.proc.on 'exit', (c) ->
                if child.running
                    grunt.log.error "child exited with code: #{c}"
                    if c is 99
                        grunt.log.writeln "example: respawning child on save"
                        child.running = false
                        setTimeout spawn, 1000, child
                        grunt.task.run 'watch'
                    else
                        process.exit c
            done()

        setTimeout spawn, 1000, child # 1 second later