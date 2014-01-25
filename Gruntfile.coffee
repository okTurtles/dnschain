'use strict'

module.exports = (grunt)->
    # load all grunt tasks
    (require 'matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

    _ = grunt.util._
    path = require 'path'
    util = require 'util'
    child_process = require 'child_process'

    # Project configuration.
    grunt.initConfig { # <-- Per helpful-convention, require braces around long blocks
    
        pkg: grunt.file.readJSON('package.json')

        coffeelint:
            gruntfile: ['<%= watch.gruntfile.files %>']
            src: ['<%= watch.src.files %>']
            options:
                configFile: "coffeelint.json"

        coffee:
            src:
                expand: true
                cwd: 'src/'
                src: ['**/*.coffee']
                dest: 'out/'
                ext: '.js'

        watch:
            options:
                spawn: true
            gruntfile:
                files: 'Gruntfile.coffee'
                tasks: ['coffeelint:gruntfile']
            src:
                files: ['src/**/*.coffee']
                tasks: ['coffeelint:src', 'coffee:src', 'example:respawn']

        clean: ['out/']

        nodemon:
            dev:
                script: 'src/example/example.coffee'
                watch: ['src']
                delayTime: 1000 # 1 second
                ext: 'js,coffee'
            dev2:
                watch: ['src']
                delayTime: 1000 # 1 second
                ext: 'js,coffee'
                exec: 'coffee'
                args: ['src/example/example.coffee', '-n']

        concurrent:
            dev:
                tasks: ['nodemon:dev', 'watch']
                options:
                    logConcurrentOutput: true
    
    } # <-- Per helpful-convention, require braces around long blocks

    grunt.event.on 'watch', (action, files, target)->
        grunt.log.writeln "#{target}: #{files} has #{action}"

        # coffeelint
        grunt.config ['coffeelint', target], src: files

        # coffee
        if target != 'gruntfile'
            coffeeData = grunt.config ['coffee', target]
            files = [files] if _.isString files
            files = files.map (file)-> path.relative coffeeData.cwd, file
            coffeeData.src = files
            grunt.config ['coffee', target], coffeeData

    # tasks.
    grunt.registerTask 'compile', ['coffeelint', 'coffee']
    grunt.registerTask 'default', ['compile']
    # grunt.registerTask 'dev', ['compile', 'concurrent:dev']
    # grunt.registerTask 'dev', ['compile', 'nodemon:dev2']


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
            child.proc.kill('SIGINT') # nicer...

        spawn = (child) ->
            grunt.log.writeln "example: spawning child..."
            child.proc = child_process.fork grunt.config('nodemon.dev.script')
            child.running = true
            child.proc.on 'exit', (c) ->
                if child.running
                    grunt.log.error "child exited with code: #{c}"
                    process.exit(c)
            done()

        setTimeout spawn, 1000, child # 1 second later