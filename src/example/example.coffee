renameDeps =
    _   : 'lodash-contrib'
    S   : 'string'
    cli : 'cli-color'

for d,dep of renameDeps
    eval "var #{d} = require('#{dep}');"

for d in ['net', 'dns', 'http', 'url', 'util', 'os', 'inquirer']
    eval "var #{d} = require('#{d}');"

console.log "Demo starting..."

DNSNMC = require('../lib/dnsnmc')

console.log "DEMO (external IP: %s)", DNSNMC.externalIP()
console.log "\nPlease enter RPC info for namecoind:\n"

questions = [
    name: 'user'
    message: 'rpc user: '
   ,
    name: 'pass'
    type: 'password'
    message: 'rpc pass: '
   ,
    name: 'host'
    message: 'rpc host: '
    default: '127.0.0.1'
   ,
    name: 'port'
    message: 'rpc port: '
    default: 8336
    filter: parseInt
]

# TODO: read these values from ~/.namecoin/namecoin.conf

# prevent inquirer from showing password length
# https://github.com/SBoudrias/Inquirer.js/issues/91
do ->
    inquirer.prompts.password::onKeypress = ->
    write = inquirer.prompts.password::write
    inquirer.prompts.password::write = (x) ->
        poop = cli.cyan('**')+'\n'
        x = '\n' if S(x).endsWith poop.slice poop.indexOf('**')
        write.bind(this)(x)
        this

server = undefined

die = ->
    console.log "got kill signal!"
    server?.shutdown()
    setImmediate -> process.exit(0)

process.on 'SIGTERM', die
process.on 'SIGINT', die
process.on 'disconnect', die

inquirer.prompt questions, (rpcOpts) ->
    console.log "launching DNSNMC with args: %j", rpcOpts
    server = DNSNMC.createServer rpcOpts

