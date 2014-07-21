module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    unblockSettings = gConf.get "unblock"
    @log = gNewLogger "Unblock"

    @isHijacked = (domain) ->
        name = domain.split "."
        unblockSettings.domainList[name[-2..].join(".")] or unblockSettings.domainList[name[-3..].join(".")] or null

    @
