###

dnsnmc
http://dnsnmc.net

Copyright (c) 2013 Greg Slepak
Licensed under the BSD 3-Clause license.

###

# TODO: go through 'TODO's!

'use strict'

module.exports = (dnsnmc) ->
    # expose these into our namespace
    for k of dnsnmc.globals
        eval "var #{k} = dnsnmc.globals.#{k};"

    ResolverStream = require('./resolver-stream')(dnsnmc)

    class DNSServer
        constructor: (@dnsnmc) ->
            @log = @dnsnmc.log.child server: "dnsnmc#{@dnsnmc.count}-DNS"

            # localize some values from the parent DNSNMC server (to avoid extra typing)
            _.merge @, _.pick(@dnsnmc, ['dnsOpts', 'nmc'])

            @server = dns2.createServer() or tErr "dns2 create"
            @server.on 'request', @callback.bind(@)
            @server.serve(@dnsOpts.port @dnsOpts.host) or tErr "dns serve"
            @log.info 'started DNS:', @dnsOpts

        shutdown: ->
            @log.debug 'shutting down!'
            @server.close()

        namecoinizeDomain: (domain) ->
            nmcDomain = S(domain).chompRight('.bit').s
            if (dotIdx = domain.indexOf('.')) != -1
                nmcDomain = nmcDomain.slice(dotIdx+1) # rm subdomain
            'd/' + nmcDomain # add 'd/' namespace

        deferQuestion: (q, res) ->
            req = dns2.Request {question: q, server: @dnsOpts.fallbackDNS}
            success = false

            req.on 'message', (err, answer) =>
                if !err? and answer.answer.length > 0
                    success = true
                    res.answer.push.apply(res.answer, answer.answer.map dns2.A)
                    res.send()
            
            req.on 'done', =>
                unless success
                    @log.warn {fn:'deferQuestion', req:req}, "defer failed"
                    @sendErr res

        sendErr: (res, code) ->
            res.header.rcode = code ? dns2.consts.NAME_TO_RCODE.SERVFAIL
            @log.warn {fn: 'sendErr', response: res}, "sending back error #{code}: #{dns2.RCODE_TO_NAME[code]}"
            res.send()

        callback: (req, res) ->
            @log.debug fn:'callback', req

            # answering multiple questions in a query appears to be problematic,
            # and few servers do it, so we only answer the first question:
            # https://stackoverflow.com/questions/4082081/requesting-a-and-aaaa-records-in-single-dns-query
            question = req.question[0]
            domain = question.name
            length = domain.length
            # TODO: pick an appropriate TTL value
            ttl = Math.floor(Math.random() * 3600) + 30

            if question.type != 'A' # TODO: handle AAAA!
                @log.debug deffering: question.type, "deferring resolution"
                @deferQuestion(question, res) # deferQuestion handles sending response
            else
                if S(domain).endsWith '.bit'
                    nmcDomain = @namecoinizeDomain domain
                    @nmc.name_show nmcDomain, (err, result) =>
                        if err
                            @log.error err: err, "name_show failed for: #{nmcDomain}: %s", result
                            # TODO: SEND PROPER ERROR RESPONSE BACK TO CLIENT!!
                            @sendErr res
                        else
                            @log.debug result: result, "result for name_show #{nmcDomain}"
                            info = JSON.parse result.value

                            # TODO: handle all the types specified in the specification!
                            #       https://github.com/namecoin/wiki/blob/master/Domain-Name-Specification-2.0.md
                            # TODO: handle other info outside of the specification!
                            #       - GNS support
                            #       - DNSSEC/DANE support?

                            # According to NMC specification, specifying 'ns'
                            # overrules 'ip' value, so check it here and resolve using
                            # old-style DNS.
                            if info.ns?.length > 0
                                # 1. Create a stream of nameserver IP addresses out of info.ns
                                # 2. Send request to each of the servers, separated by a two
                                #    second delay. On receiving the first answer from any of
                                #    them, cancel all other pending requests and respond to
                                #    our client.
                                # 
                                # TODO: handle ns = IPv6 addr!
                                nsIPs = []
                                nsCNAMEs = []
                                for ip in info.ns
                                    (if net.isIP(ip) then nsIPs else nsCNAMEs).push(ip)

                                # ResolverStream will clone these in the constructor
                                resolvOpts =
                                    log         : @log.bind(@)
                                    stackedDelay: 0

                                nsCNAME2IP = new ResolverStream resolvOpts

                                nsIPs = es.merge(sa(nsIPs), sa(nsCNAMEs).pipe(nsCNAME2IP))

                                # safe to do becase ResolverStream clones the opts
                                resolvOpts.stackedDelay = 2000
                                resolvOpts.reqMaker = (cname) -> # -> bc @nsIP
                                    req = dns2.Request
                                        question: dns2.Question {name:cname, type:'A'}
                                        server: {address: @nsIP.slice(0)} #copy it!

                                stackedQuery = new ResolverStream resolvOpts
                                stackedQuery.errors = 0

                                nsIPs.on 'data', (nsIP) ->
                                    stackedQuery.nsIP = nsIP
                                    stackedQuery.write nmcDomain

                                stackedQuery.on 'answer', (answer) =>
                                    nsCNAME2IP.cancelRequests(true)
                                    stackedQuery.cancelRequests(true)
                                    res.answer.push.apply(res.answer, answer.answer.map dns2.A)
                                    @log.debug {fn: 'callback->answer', res: res.answer}, "sending answer!"
                                    res.send()

                                stackedQuery.on 'error', (err) =>
                                    if ++stackedQuery.errors == info.ns.length
                                        @log.warn {fn:'cb[stackedQErr]', err:err}, "errors on all NS!"
                                        @sendErr(res)

                            else if info.ip
                                # we have its IP! send reply to client
                                # TODO: pick an appropriate 'ttl' for the response!
                                # TODO: handle more info! send the rest of the
                                #       stuff in 'info', and all the IPs!
                                info.ip = [info.ip] if typeof info.ip is 'string'
                                res.answer.push.apply(res.answer, info.ip.map ip2type(domain, ttl))
                                @log.debug {fn: 'callback', info: info, domain: nmcDomain, res: res.answer}, "direct IP stored in blockchain!"
                                res.send()
                            else
                                @log.error {fn: 'callback', info:info}, "no IP or NS in info"
                                @sendErr(res, dns2.consts.NAME_TO_RCODE.NOTFOUND)
                            # TODO: handle info.ip6!
                
                else if S(domain).endsWith '.nmc'
                    ourIP = externalIP()
                    @log.debug "request for %s! sending our IP: %s", domain, ourIP
                    res.answer.push ip2type(domain,ttl)(ourIP)
                    res.end()
                else
                    dns.resolve4 domain, (err, addrs) =>
                        if err
                            @log.debug "resolve4 error: " + err
                            @sendErr(res)
                        else
                            res.answer.push.apply(res.answer, addrs.map ip2type(domain, ttl))
                            res.send()
