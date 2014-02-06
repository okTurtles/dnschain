#!/usr/bin/env coffee

deps =
    _   : 'lodash-contrib'
    S   : 'string'
    prop: 'properties'
    log : 'winston'

for d in ['path', 'fs', 'util', 'os', 'inquirer', 'child_process']
    deps[d] = d

for k,v of deps
    eval "var #{k} = require('#{v}');"

log.cli()

log.error "Sorry, for now you'll need to manually install and edit the dnschain.service file."
log.error "You can help us finish implementing this little utility by implementing the", "portmap".bold, "command to dnschain."
log.error "portmap".bold, "will allow us to only have one", "ExecStartPre".cyan, "key in the service file, making it work with the nodejs properties module."
log.error "Alternatively, you can help make this work with that module (though that's not the ideal solution)."

process.exit 1

pOpts =
    sections: true
    replacer: ->
        pOpts._separator = "=" # hack to remove spaces b/w keys & vals
                               # to match systemd unit file convention
        @assert()

unitPath = path.join __dirname, 'dnschain.service'
unitStr = fs.readFileSync unitPath, encoding: 'utf8'

unit = prop.parse unitStr, pOpts


child_process.exec "npm -g bin", (err, stdout, stderr) ->
    if err
        log.error "Failed to run 'npm -g bin'! Make sure 'npm' is installed and accessible through your PATH environment variable!"
        log.error(stdout) if stdout? and stdout != ''
        log.error(stderr) if stderr? and stderr != ''
        log.error err.stack
        process.exit 1
    else
        questions = [
            name: 'User'
            message: 'Run as user: '
            default: unit.Service.User
           ,
            name: 'Group'
            message: 'Run as group: '
            default: unit.Service.Group
           ,
            name: 'WorkingDirectory'
            message: 'Working directory: '
            default: unit.Service.WorkingDirectory
           ,
            name: 'ExecStart'
            message: 'Full dnschain command to run: '
            default: path.join S(stdout).trim().s, 'dnschain'
           ,
            name: 'path'
            message: 'Save dnschain.service in: '
            default: '/etc/systemd/system'
            filter: (p) -> path.join p, "dnschain.service"
        ]

        log.info "Provide configuration info for running 'dnschain':\n"
        inquirer.prompt questions, (answers) ->
            _.assign unit.Service, _.omit(answers, 'path')
            stringifier = prop.createStringifier()
            for section of unit
                stringifier.section section
                for k,v of unit[section]
                    stringifier.property {key: k, value: v}

            unitStr = prop.stringify stringifier, pOpts

            log.info "\nFinal configuration:\n\n%s\n", unitStr.split('\n').map((l)->"   #{l}").join('\n')

            v = (s) -> /^[yn]s*$/i.test s
            inquirer.prompt [{name:'yes',message:'Write file? (y/n)',validate:v}], (confirm)->
                if confirm.yes.toLowerCase() is 'y'
                    fs.writeFile answers.path, unitStr, mode: 0o644, (err) ->
                        if err
                            log.error err.stack
                            process.exit 1
                        else
                            log.info "Wrote:  #{answers.path.bold.cyan}\n\nNow enable and start the service using the #{'systemctl'.bold.green} command."
