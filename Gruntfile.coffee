'use strict'

module.exports = (grunt)->
    # load all grunt tasks
    (require 'matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

    _ = grunt.util._
    # path = require 'path'

    # Project configuration.
    grunt.initConfig { # <-- Per smart-convention, require braces around long blocks
    
        pkg: grunt.file.readJSON('package.json')

        coffeelint:
            gruntfile: ['<%= watch.gruntfile.files %>']
            lib: ['<%= watch.lib.files %>']
            options:
                configFile: "coffeelint.json"

        coffee:
            lib:
                expand: true
                cwd: 'src/lib/'
                src: ['**/*.coffee']
                dest: 'out/lib/'
                ext: '.js'

        watch:
            options:
                spawn: false
            gruntfile:
                files: 'Gruntfile.coffee'
                tasks: ['coffeelint:gruntfile']
            lib:
                files: ['src/lib/**/*.coffee']
                tasks: ['coffeelint:lib', 'coffee:lib']

        clean: ['out/']
    
    } # <-- Per smart-convention, require braces around long blocks

    grunt.event.on 'watch', (action, files, target)->
        grunt.log.writeln "#{target}: #{files} has #{action}"

        # coffeelint
        grunt.config ['coffeelint', target], src: files

        # coffee
        coffeeData = grunt.config ['coffee', target]
        files = [files] if _.isString files
        files = files.map (file)-> path.relative coffeeData.cwd, file
        coffeeData.src = files

        grunt.config ['coffee', target], coffeeData

    # tasks.
    grunt.registerTask 'compile', [
        'coffeelint'
        'coffee'
    ]
    grunt.registerTask 'default', [
        'compile'
    ]

