###

dnschain
http://dnschain.net

Copyright (c) 2013-2014 Greg Slepak

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

###

module.exports = (dnschain) ->
    # expose these into our namespace
    for k of dnschain.globals
        eval "var #{k} = dnschain.globals.#{k};"

    QTYPE_NAME = dns2.consts.QTYPE_TO_NAME
    NAME_QTYPE = dns2.consts.NAME_TO_QTYPE
    NAME_RCODE = dns2.consts.NAME_TO_RCODE
    RCODE_NAME = dns2.consts.RCODE_TO_NAME
    BLOCKS2SEC = 10 * 60


    # It is the hander's job to add answers to 'res' but *NOT* to send them!
    # Instead, it should call the callback function 'cb'.
    # Pass in a NAME_RCODE to 'cb' on error, or nothing on success.
    # 
    # IMPORTANT: these functions __*MUST*__ be bound to the DNSServer instance 
    #            that calls them!
    dnsTypeHandlers =
        namecoin:
            # TODO: handle all the types specified in the specification!
            #       https://wiki.namecoin.info/index.php?title=Domain_Name_Specification#Value_field
            #       
            # TODO: handle other info outside of the specification!
            #       - GNS support
            #       - DNSSEC support?
            #       
            # *ALL* namecoin handlers must be of the this type
            A: (req, res, qIdx, data, cb) ->
                info = data.value
                q = req.question[qIdx]
                ttl = data.expires_in? * BLOCKS2SEC
                # According to NMC specification, specifying 'ns'
                # overrules 'ip' value, so check it here and resolve using
                # old-style DNS.
                if info.ns?.length > 0
                    # 1. Create a stream of nameserver IP addresses out of info.ns
                    # 2. Send request to each of the servers, separated by `stackedDelay`.
                    #    On receiving the first answer from any of them, cancel all other
                    #    pending requests and respond to our client.
                    # 
                    # TODO: handle ns = IPv6 addr!
                    [nsIPs, nsCNAMEs] = [[],[]]

                    for ip in info.ns
                        (if net.isIP(ip) then nsIPs else nsCNAMEs).push(ip)

                    # ResolverStream will clone 'resolvOpts' in the constructor
                    nsCNAME2IP = new ResolverStream(resolvOpts = log:@log)

                    nsIPs = es.merge(sa(nsIPs), sa(nsCNAMEs).pipe(nsCNAME2IP))

                    # safe to do becase ResolverStream clones the opts
                    resolvOpts.stackedDelay = 1000
                    resolvOpts.reqMaker = (nsIP) =>
                        req = dns2.Request
                            question: q
                            server: {address: nsIP}

                    stackedQuery = new ResolverStream resolvOpts
                    stackedQuery.errors = 0

                    nsIPs.on 'data', (nsIP) ->
                        stackedQuery.write nsIP

                    stackedQuery.on 'error', (err) =>
                        if ++stackedQuery.errors == info.ns.length
                            @log.warn "errors on all NS!", {fn:'A', q:q, err:err}
                            cb NAME_RCODE.SERVFAIL

                    stackedQuery.on 'answers', (answers) =>
                        nsCNAME2IP.cancelRequests(true)
                        stackedQuery.cancelRequests(true)
                        res.answer.push answers...
                        cb()

                else if info.ip
                    # we have its IP! send reply to client
                    # TODO: handle more info! send the rest of the
                    #       stuff in 'info', and all the IPs!
                    info.ip = [info.ip] if typeof info.ip is 'string'
                    # info.ip.forEach (a)-> res.answer.push ip2type(q.name, ttl)(a)
                    res.answer.push (info.ip.map ip2type(q.name, ttl))...
                    cb()
                else
                    @log.warn {fn: 'nmc_show|404', q:q}
                    cb NAME_RCODE.NOTFOUND
            # /end 'A'

            # TODO: implement this!
            AAAA: (req, res, qIdx, data, cb) ->
                cb NAME_RCODE.NOTIMP
            
            TLSA: (req, res, qIdx, data, cb) ->
                len = res.answer.length
                ttl = data.expires_in? * BLOCKS2SEC
                q = req.question[qIdx]
                if info = data.value
                    res.answer.push tls2tlsa(info.tls, ttl, q.name)...
                # check if any records were added
                if res.answer.length - len is 0
                    @log.warn {fn: 'TLSA|404', q:q, data:data}
                    cb NAME_RCODE.NOTFOUND
                else
                    cb()

            ANY: ->
                # TODO: loop through 'data.value' and call approrpriate handlers
                # TODO: enable EDNS reply
                dnsTypeHandlers.namecoin.A.apply @, [].slice.call arguments