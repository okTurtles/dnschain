###

dnschain
http://dnschain.org

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

        coffeelint:
            gruntfile: ['<%= watch.gruntfile.files %>']
            src: ['<%= watch.src.files %>']
            options:
                configFile: "coffeelint.json"
        watch:
            options:
                spawn: true
            gruntfile:
                files: 'Gruntfile.coffee'
                tasks: ['coffeelint:gruntfile']
            src:
                files: ['src/**/*.coffee']
                tasks: ['coffeelint:src', 'example:respawn']

    grunt.event.on 'watch', (action, files, target)->
        grunt.log.writeln "#{target}: #{files} has #{action}"
        grunt.config ['coffeelint', target], src: files

    # tasks.
    grunt.registerTask 'default', ['example']

    grunt.registerTask 'example', 'Run Example', ->
        # prevent watch from spawning. if we don't do this, we won't be able
        # to kill the child when files change.
        grunt.config ['watch', 'options'], spawn: false
        grunt.task.run 'example:respawn', 'watch'

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
                    process.exit c
            done()

        setTimeout spawn, 1000, child # 1 second later