die = ->
    console.log "got kill signal!"
    server?.shutdown()
    setImmediate -> process.exit 0

process.on 'SIGTERM', die
process.on 'SIGINT', die
process.on 'disconnect', die

console.log "Demo starting..."
server = (require '../lib/dnsnmc').createServer()
