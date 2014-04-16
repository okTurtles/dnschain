# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain (formerly DNSNMC) makes it possible to be certain that you're communicating with who you want to communicate with, and connecting to the sites that you want to connect to, *without anyone secretly listening in on your conversations in between.*

- [What is it?](#What)
    - [DNSChain "stops the NSA" by fixing HTTPS/TLS](#DNSChain)
    - [Simple and secure GPG key distribution](#GPG)
    - [Free SSL certificates become possible](#Free)
    - [The `.dns` meta-TLD](#metaTLD)
- [How do I use it?](#Use)
    - [Free public DNSChain servers](#Servers)
    - [Registering `.bit` domains and identities](#Registering)
- [How do I run my own DNSChain server?](#Run)
    - [Requirements](#Requirements)
    - [Getting Started](#Getting)
    - [Configuration](#Configuration)
    - [Working with the source](#Working)
- [Community](#Community)
- [Contributing](#Contributing)
    - [Contributors](#Contributors)
    - [TODO](#TODO)
- [Release History](#Release)
- [License](#License)

## What is it?<a name="What"/>

### DNSChain "stops the NSA" by fixing HTTPS/TLS<a name="DNSChain"/>

In spite of their names, [SSL/TLS and HTTPS are not secure](http://okturtles.com/other/dnsnmc_okturtles_overview.pdf).

DNSChain fixes this. What is DNSChain?

- It's a DNS server that supports old-school DNS, and [blockchain](https://en.bitcoin.it/wiki/Block_chain)-based DNS (Namecoin currently), giving you access to `*.bit` websites.
- It creates the __.dns meta-TLD__. Each `.dns` "[TLD](https://en.wikipedia.org/wiki/Top-level_domain)" belongs to just one DNSChain server: the one you're connected to.
- It's an HTTP server (and in the future, an HTTPS server)
- It lets you communicate directly with information in blockchains (read, and maybe even write!) from [JavaScript apps](http://okturtles.com)!
- At its core, it lets you connect to websites, chat with your friends, and be safe from eavesdroppers and Big Brother-type entities. It gives you the gift of **authentication**.

It's also only about *600 lines of easy to understand CoffeeScript!* This means that even mere mortals can look at the code, and verify for themselves that it is safe to run on their systems.

### Simple and secure GPG key distribution<a name="GPG"/>

![Easily share your GPG key!](https://www.taoeffect.com/includes/images/twitter-gpg-s.jpg)

Well, simple to share, a little more difficult to register it (at the moment only, give it time ^_^):

1. Use `namecoind` to [register](https://github.com/namecoin/wiki/wiki/Register-and-Configure-.bit-Domains) your identity in the `id/` [namespace](https://github.com/namecoin/wiki/wiki/Identity).
2. Use a DNSChain server that exposes its `.dns` meta-TLD through the traditional DNS, as shown in the screenshot.

It's always best to use your own server, of course. _Note: headers containing a crypographic signature will be sent soon!_

### Free SSL certificates become possible<a name="Free"/>

SSL certificates today [do not provide the security that they claim to provide](http://okturtles.com/other/dnsnmc_okturtles_overview.pdf). DNSChain replaces Certificate Authorities by providing a means for distributing public keys in a way that is secure from MITM attacks.

### The `.dns` meta-TLD<a name="metaTLD"/>

__.dns__ is a "meta-TLD" because unlike traditional TLDs, it is not meant to globally resolve to a specific IP. Rather, it is meant to resolve to a DNSChain server that *_you personally own and run_*.

It bears emphasizing that *you cannot register a meta-TLD because you already own them!*

When a DNSChain server sees a request to a `.dns` domain, it handles the request itself, looking it up in a blockchain stored on that same server. At the moment, DNSChain uses the Namecoin blockchain, but it can easily be configured to use any blockchain.

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

We'll post the public keys for these servers here as well once signed DNS & HTTP responses are implemented. Note that DNSChain + DNSCrypt servers already already guarantee the authenticity of DNS responses.

### Registering `.bit` domains and identities<a name="Registering"/>

`.bit` domains and public identities are currently stored in the Namecoin P2P network. It's very similar to the Bitcoin network.

All of this must currently be done using `namecoind`, a daemon that DNSChain requires running in the background to access the Namecoin network.

See the [Namecoin wiki](https://github.com/namecoin/wiki/wiki) for more info:

- [Registering .bit domains](https://github.com/namecoin/wiki/wiki/Register-and-Configure-.bit-Domains)
- [Global public identities specification](https://github.com/namecoin/wiki/wiki/Identity)

## How do I run my own?<a name="Run"/>

Get yourself a Linux server (they come as cheap as $2/month), and then make sure you have the following software installed:

#### Requirements<a name="Requirements"/>

1. `nodejs` and `npm` - We recommend using a package manager to install them.
2. [coffee-script](https://github.com/jashkenas/coffee-script) (version 1.7.1+) - install via `npm install -g coffee-script`
3. `grunt-cli` - install via `npm install -g grunt-cli`, provides the `grunt` command.
4. `namecoind` - [instructions](https://github.com/namecoin/wiki/wiki/Install-and-Configure-Namecoin)

<!--5. `libgmp` - needed by Mozilla's [jwcrypto](https://github.com/mozilla/jwcrypto), install using `apt-get install libgmp-dev` (Debian) or `brew install gmp` (OS X).

DNSChain __does not use the NodeJS crypto module__ for generating signed headers because that module uses `OpenSSL` (which is considered harmful [1](http://www.peereboom.us/assl/assl/html/openssl.html)[2](https://www.openssl.org/news/vulnerabilities.html)). Instead, Mozilla's [jwcrypto](https://github.com/mozilla/jwcrypto) is used.-->

#### Getting Started<a name="Getting"/>

1. Install DNSChain using: `npm install -g dnschain` (you may need to put `sudo` in front of that).
2. Run `namecoind` in the background. You can use `systemd` and create a `namecoin.service` file for it based off of [dnschain.service](scripts/dnschain.service).

Test DNSChain by simply running `dnschain` from the command line (developers [see here](#Working)). Have a look at the configuration section below, and when you're ready, run it in the background as a daemon. As a convenience, DNSChain [comes with a `systemd` unit file](scripts/dnschain.service) that you can use to run it.

#### Configuration<a name="Configuration"/>

DNSChain uses the wonderful [`nconf` module](https://github.com/flatiron/nconf) for all of its configuration purposes. This means that you can configure it using files, command line arguments, and environment variables.

There are two configurations to be aware of (both loaded using `nconf`): DNSChain's, and `namecoind`'s:

- `dnschain.conf` locations (in order of preference):
    - `$HOME/.dnschain.conf`
    - `$HOME/.dnschain/dnschain.conf`
    - `/etc/dnschain/dnschain.conf`
- `namecoin.conf` locations (in order of preference):
    - `$HOME/.namcoin/namcoin.conf`

DNSChain will fetch the RPC username and password out of Namecoin's configuration file if it can find it. If it can't, you'll either need to fix that, or provide `rpcuser`, `rpcpassword`, etc. to it via command line arguments or environment variables.

The format of the configuration file is similar to INI, and is parsed by the NodeJS [`properties` module](https://github.com/gagle/node-properties) (in tandem with `nconf`). Here's a very basic `dnschain.conf`:

    [log]
    level=info

    [dns]
    port=5333

    [http]
    port=8088
    tlsPort=4443

**Have a look at [config.coffee](src/lib/config.coffee) to see all the possible configuration options and defaults!**

#### Working with the source<a name="Working"/>

Run `sudo grunt example` from the DNSChain repository that you cloned from here.

Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

## Community<a name="Community"/>

- IRC (Freenode): `#dnschain` &rArr; [Webchat](http://webchat.freenode.net/?channels=%23dnschain&uio=MT11bmRlZmluZWQb1)
- [Forums](https://forums.okturtles.com/) __We use a self-signed cert!__ Tell your browser to store it permanently.
    - HTTPS fingerprint for `d/okturtles`: [http://dns.dnschain.net/d/okturtles](http://dns.dnschain.net/d/okturtles)
- Twitter: [@DNSChain](https://twitter.com/dnschain)
- Email: hi at okturtles.com

## Contributing<a name="Contributing"/>

To test and develop at the same time, simply run `sudo grunt example` and set your computer's DNS to use `127.0.0.1`. Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

#### Contributors<a name="Contributors"/>

- [Greg Slepak](https://twitter.com/taoeffect) (Original author and current maintainer)
- [Matthieu Rakotojaona](https://otokar.looc2011.eu/) (DANE/TLSA support and misc. fixes)
- *Your name & link of choice here!*

#### TODO<a name="TODO"/>

See TODOs in source, below is only a partial list.

- __BUG:__ Fix ANY-record type resolution for .bit and .dns domains.
- sign responses
- add DANE support ([coming soon thanks to @rakoo!](https://github.com/rakoo/dnschain/commit/0dae9ab2cb3dc7df597b4b82511d219a2ff446c0))
- Support command line arguments
    - `portmap` for `iptables` support.
    - `-v`
    - `-h`

## Release History<a name="Release"/>

| Version |       Date       |                                                                                                                                      Notes                                                                                                                                      |
| ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0.0.2   | April 15, 2014   | <ul><li>Enabled [namespace syntax](https://github.com/gagle/node-properties#namespaces) for the config file</li><li>Cherry-picked fix for `namecoinizeDomain` by @rakoo (thanks!)</li><li>Added more public servers added to README.md</li><li>Added example systemd unit files for `namecoind` and `dnscrypt-wrapper` to scripts folder</li> </ul> |
| 0.0.1   | February 9, 2014 | Published to `npm` under `dnschain`                                                                                                                                                                                                                                             |

Copyright (c) 2013-2014 Greg Slepak. Licensed under the BSD 3-Clause license.
