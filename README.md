# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain (formerly DNSNMC) makes it possible to be certain that you're communicating with who you want to communicate with, and connecting to the sites that you want to connect to, *without anyone secretly listening in on your conversations in between.*

- [What is it?](#What)
    - [DNSChain replaces X.509 PKI with the blockchain](#DNSChain)
    - [Simple and secure GPG key distribution](#GPG)
    - [Free SSL certificates become possible](#Free)
    - [Prevents DDoS attacks](#DDoS)
    - [Certificate revocation that actually works](#Revocation)
    - [DNS-based censorship circumvention](#Censorship)
    - [MITM-proof authentication via `.dns` metaTLD](#metaTLD)
- [How do I use it?](#Use)
    - [Free public DNSChain servers](#Servers)
    - [Registering `.bit` domains and identities](#Registering)
- [How do I run my own DNSChain server?](#Run)
- [Community](#Community)
- [Contributors](#Contributors)
- [Release History](#Release)
- [License](#License)

## What is it?<a name="What"/>

### DNSChain replaces X.509 PKI with the blockchain<a name="DNSChain"/>

[X.509 PKI](https://en.wikipedia.org/wiki/X.509) makes and breaks today's Internet security. It's what makes your browser
think ["The connection to this website is secure"](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/) when [it's not](http://okturtles.com/#not-secure).
It's what we have to get rid of, and DNSChain provides a scalable, distributed, and decentralized replacement that doesn't depend on untrustworthy
"authority figures":
︎

|                                                                              |      DNSChain      | X.509 PKI [with or without Certificate Transparency](http://blog.okturtles.com/2014/09/the-trouble-with-certificate-transparency/) |
|------------------------------------------------------------------------------|--------------------|------------------------------------------------------------------------------------------------------------------------------------|
| __MITM-proof authentication__ <sup>[[1]](#metaTLD)</sup>                     | :white_check_mark: | :x:                                                                                                                                |
| __Secure and simple [GPG key distribution](#GPG)__                           | :white_check_mark: | :x:                                                                                                                                |
| __Free and actually-secure SSL certificates__ <sup>[[2]](#Free)</sup>        | :white_check_mark: | :x:                                                                                                                                |
| __Stops many denial-of-service attacks__ <sup>[[3]](#DDoS)</sup>             | :white_check_mark: | :x:                                                                                                                                |
| __Certificate revocation that actually works__ <sup>[[4]](#Revocation)</sup> | :white_check_mark: | :x:                                                                                                                                |
| __DNS-based censorship circumvention__ <sup>[[5]](#Censorship)</sup>         | :white_check_mark: | :x:                                                                                                                                |
| __Prevents [domain theft](http://okturtles.com/#open-source) ("seizures")__  | :white_check_mark: | :x:                                                                                                                                |
| __Access blockchain-based [domains like `.bit`](#Use)__                      | :white_check_mark: | :x:                                                                                                                                |
| __RESTful API to blockchain via [.dns metaTLD](#metaTLD)__                   | :white_check_mark: | :x:                                                                                                                                |
| __Simple design fits in about *600 lines of CoffeeScript!*__                 | :white_check_mark: | :x:                                                                                                                                |

### Simple and secure GPG key distribution<a name="GPG"/>

![Easily share your GPG key!](https://www.taoeffect.com/includes/images/twitter-gpg-s.jpg)

Well, simple to share, a little more difficult to register it (at the moment only, give it time ^_^):

1. Use `namecoind` to [register](https://github.com/namecoin/wiki/wiki/Register-and-Configure-.bit-Domains) your identity in the `id/` [namespace](https://github.com/namecoin/wiki/wiki/Identity).
2. Use a DNSChain server that exposes its `.dns` meta-TLD through the traditional DNS, as shown in the screenshot.

It's always best to use your own server, of course. _Note: headers containing a crypographic signature will be sent soon!_

### Free SSL certificates become possible<a name="Free"/>

SSL certificates today __[do not provide the security that they claim to provide](http://okturtles.com/#not-secure)__. DNSChain replaces Certificate Authorities by providing a means for distributing public keys in a way that is secure from MITM attacks.

### Prevents DDoS attacks<a name="DDoS"/>

Unlike traditional DNS servers, DNSChain encourages widespread deployment of the server (ideally, "one for every group of friends").
This distributed, flat topology eliminates the need for open resolvers by making it practical to limit clients to a small, trusted set.
Additionally, whereas traditional DNS resolvers must query other DNS servers to answer queries, blockchain-based DNS resolvers have no
such requirement because *all* of the data necessary to answer queries is stored locally on the server.

Another DoS attack relates to the centralized manner in which today's SSL certificates are checked for revocation:

### Certificate revocation that actually works<a name="Revocation"/>

TODO: [OCSP](https://news.ycombinator.com/item?id=7556909) + DoS.

### DNS-based censorship circumvention<a name="Censorship"/>

The developers of [Unblock.us.org](https://github.com/SGrondin/unblock.us.org) and DNSChain are teaming up to bring the anti-censorship features of Unblock.us into DNSChain. Each project benefits from the other: DNSChain ensures MITM-free communication and Unblock.us ensures that the communication passes through firewalls.

The Unblock.us feature is optional and is up to the server administrator to enable and configure to their needs. It uses MITM to defeat censorship at its own game.

Unblock.us works by hijacking the DNS lookups for the domains on a list defined by the server administrator. The server then accepts all HTTP and HTTPS traffic addressed to those domains and forwards it intelligently. Even though it can't decrypt SSL traffic, it can still forward it. It's as fast as a VPN (unlike Tor) and ONLY tunnels the traffic to those domains, meaning that it doesn't affect other online activites (unlike VPNs and Tor) and isn't costly in server bandwidth. Finally, there's no software to install, only DNS settings to change. It has been confirmed to work in Turkey, UK, Kuwait, UAE and many additional Middle Eastern countries.

For now, Deep Packet Inspection techniques used in Pakistan and China can still beat Unblock.us, but the next version will address that issue using a technique called [Host Tunneling](http://unblock.us.org/?p=61). Short of cutting entire countries off the internet, DNSChain/Unblock.us will be able to get through.

### The `.dns` meta-TLD<a name="metaTLD"/>

__.dns__ is [a meta-TLD](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/) because unlike traditional TLDs, it is not meant to globally resolve to a specific IP. Rather, it is meant to resolve to a DNSChain server that *_you personally own and run_*.

It bears emphasizing that *you cannot register a meta-TLD because you already own them!*

When a DNSChain server sees a request to a `.dns` domain, it handles the request itself, looking it up in a blockchain stored on that same server. At the moment, DNSChain uses the Namecoin blockchain, but it can easily be configured to use any blockchain.

- More info: [_Introducing the dotDNS metaTLD_](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/)

## How do I use it?<a name="Use"/>

No special software is required, just set your computer's DNS settings to use [one of the public DNSChain servers](#Servers) (more secure to run your own though).

Then try the following:

- Visit [http://okturtles.bit](http://okturtles.bit)
- "What's the domain info for `okturtles.bit`?" [http://namecoin.dns/d/okturtles](http://namecoin.dns/d/okturtles)
- "Who is Greg and what is his GPG info?" [http://namecoin.dns/id/greg](http://namecoin.dns/id/greg)

__Don't want to change your DNS settings?__

As a convenience, the first DNSChain server's `.dns` meta-TLD can be accessed over the old-DNS by way of `dns.dnschain.net`, like so:

- "Who is Greg?" [http://dns.dnschain.net/id/greg](http://dns.dnschain.net/id/greg)

This means you can immediately begin writing [JavaScript apps](http://okturtles.com) that query the blockchain. :)

### Free public DNSChain servers<a name="Servers"/>

*DNSChain is meant to be run by individuals!*

Yes, you can use a public DNSChain server, but it's far better to use your own because it gives you more privacy, makes you more resistant to censorship, and provides you with a stronger guarantee that the responses you get haven't been tampered with by a malicious server.

Those who do not own their own server or VPS can use their friend's (as long as they trust that person). DNSChain servers will sign all of their responses, thus protecting your from MITM attacks. *(NOTE: signing is not yet implemented, but will be soon)*

You can, if you must, use a public DNSChain server. Simply [set your computer's DNS settings](https://startpage.com/do/search?q=how+to+change+DNS+settings) to one of these. Note that some of the servers must be used with [dnscrypt-proxy](https://github.com/jedisct1/dnscrypt-proxy).

|                          IP or DNSCrypt provider                           |           [DNSCrypt](http://dnscrypt.org/) Info            | Logs |    Location    |                          Owner                          |     Notes      |
| -------------------------------------------------------------------------- | ---------------------------------------------------------- | ---- | -------------- | ------------------------------------------------------- | -------------- |
| 192.184.93.146 (aka [d/okturtles](http://dns.dnschain.net/d/okturtles))    | N/A                                                        | No   | Atlanta, GA    | [id/greg](http://dns.dnschain.net/id/greg)              |                |
| 54.85.5.167 (aka [name.thwg.org](name.thwg.org))                           | N/A                                                        | No   | USA            | [id/wozz](http://dns.dnschain.net/id/wozz)              |                |
| [2.dnscrypt-cert.okturtles.com](https://gist.github.com/taoeffect/8855230) | [Required Info](https://gist.github.com/taoeffect/8855230) | No   | Atlanta, GA    | [id/greg](http://dns.dnschain.net/id/greg)              |                |
| [2.dnscrypt-cert.soltysiak.com](http://dc1.soltysiak.com)                  | [Required Info](http://dc1.soltysiak.com)                  | No   | Poznan, Poland | [@maciejsoltysiak](https://twitter.com/maciejsoltysiak) | IPv6 available |

Tell us about yours by opening an issue (or any other means) and we'll list it here!

We'll post the public keys for these servers here as well once signed DNS & HTTP responses are implemented. Note that DNSChain + DNSCrypt servers already guarantee the authenticity of DNS responses.

### Registering `.bit` domains and identities<a name="Registering"/>

[.bit Domains and Identities](docs/dot-bit-Domains-and-Identities.md)


## How do I run my own?<a name="Run"/>

- [Requirements](docs/How-do-I-run-my-own.md#Requirements)
- [Getting Started](docs/How-do-I-run-my-own.md#Getting)
- [Configuration](docs/How-do-I-run-my-own.md#Configuration)
- [Working with the source](docs/How-do-I-run-my-own.md#Working)


## Community<a name="Community"/>

- Forums: [https://forums.okturtles.com](https://forums.okturtles.com)
- IRC Chat@Freenode: `#dnschain` &rArr; [Webchat](http://webchat.freenode.net/?channels=%23dnschain&uio=MT11bmRlZmluZWQb1)
- Twitter: [@DNSChain](https://twitter.com/dnschain)
- Twitter: [@okTurtles](https://twitter.com/okTurtles)

## Contributors<a name="Contributors"/>

- [Greg Slepak](https://twitter.com/taoeffect) (Original author and current maintainer)
- [Simon Grondin](https://github.com/SGrondin) (DNS-based censorship circumvention)
- [Matthieu Rakotojaona](https://otokar.looc2011.eu/) (DANE/TLSA contributions and misc. fixes)
- [TJ Fontaine](https://github.com/tjfontaine) (For `native-dns`, `native-dns-packet` modules and related projects)
- [Cayman Nava](https://github.com/WeMeetAgain) (Ethereum support)
- *Your name & link of choice here!*

## Release History<a name="Release"/>

###### 0.2.5 - July 10, 2014

- Fixed `.bit` resolution bug introduced in `0.2.4`

###### 0.2.4 - July 10, 2014

- Fixed installation issue caused by `json-rpc2`
- Fixed exception (issue #20)
- Prevented possible DoS on in certain server setup where DNSChain
  is combined with another DNS server

###### 0.2.3 - May 27, 2014

- Updated native-dns module
- Fixed [#16](https://github.com/okTurtles/dnschain/issues/16) (unhandled exceptions). DNSSEC and other "unhandled" packets should be relayed now as a result.

###### 0.2.2 - May 3, 2014

- Corrected StackedSchedule scheduling
- Copied old release notes to HISTORY.md

###### 0.2.1 - May 2, 2014

_(NOTE: 0.2.1 is the same as 0.2.0, just forgot to bump NPM version.)_

- __New Features:__
    + oldDNSMethod config options should can now be specified as strings
      (and should be!)
    + new oldDNSMethod `NO_OLD_DNS_EVER` prevents resolution in oldDNS
      even if the blockchain specifies it be done.
      (see comments in `globals.coffee` for more info and options)
- __Improvements:__
    + Improved logging shows file and line number for all warnings
      and errors (and for some messages of other log levels too)
    + All injected globals now start with 'g' (except for module names)
    + Faster `.bit` resolution
    + Imporved overall code quality and readability
- __Fixes:__
    + Fixed #8 (exception on NS timeout)
    + Fixed #9 (return NXDOMAIN on bad 'ns' in *.bit)

###### 0.1.1 - April 24, 2014

- __Improvements:__
    + Some improved logging
- __Fixes:__
    + Issue resolving some `.bit` domains introduced in previous release
    + `ttl` for `.bit` domains is now equal to average block creation time
    + Outdated license string in `package.json`

###### 0.1.0 - April 24, 2014

- __New Features:__
    + DANE/TLSA support for *BOTH* canonical DNS and blockchain DNS!
    + Added `NO_OLD_DNS` option for `oldDNSMethod` (refuses all non-blockchain queries)
- __Improvements:__
    + Redesigned `dns.coffee` and improved its structure
    + Accurate `ttl` values now returned for namecoin DNS queries based on `expires_in` field
    + Updated contributors, code and config examples in `README.md`
    + Improved EDNS support
    + Improved handling of ANY queries
    + Updated dependencies to latest versions
    + `native-dns` is now fetched from the `dnschain` branch of [our fork](https://github.com/okTurtles/node-dns/tree/dnschain).
    + Comments added all over the place (to `native-dns` &amp; related projects also!)
    + Many other code improvements both to DNSChain and the NodeJS `native-dns` module
    + Some performance improvements
- __Fixes:__
    + Fixed broken `grunt example`
    + Fixed some uncaught exceptions (issues #1 and #2)
    + Fixed broken NAPTR support
- __Changes:__
    + DNSChain license is now MPL-2.0 (applies to version 0.1.0 onward)
    + Default logging level is now `info`

_(For complete release history see [HISTORY.md](HISTORY.md))_

Copyright (c) 2013-2014 Greg Slepak. Licensed under [MPL-2.0 license](http://mozilla.org/MPL/2.0/).