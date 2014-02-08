# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain (formerly DNSNMC) makes it possible to be certain that you're communicating with who you want to communicate with, and connecting to the sites that you want to connect to, *without anyone secretly listening in on your conversations in between.*

- [What is it?](#What)
    - [DNSChain "stops the NSA" by fixing HTTPS](#DNSChain)
    - [Simple and secure GPG key distribution](#GPG)
    - [Free SSL certificates become possible](#Free)
- [How do I use it?](#Use)
    - [Free public DNSChain servers](#Free)
- [How do I run my own?](#Run)
    - [Requirements](#Requirements)
    - [Getting Started](#Getting)
- [Community & Contributing](#Community)
- [TODO](#TODO)
- [Release History](#Release)
- [License](#License)

## What is it?<a name="What"/>

### DNSChain "stops the NSA" by fixing HTTPS<a name="DNSChain"/>

In spite of their names, [SSL/TLS and HTTPS are not secure](http://okturtles.com/other/dnsnmc_okturtles_overview.pdf).

DNSChain fixes this. What is DNSChain?

- It's a DNS server that supports old-school DNS, and blockchain-based DNS (Namecoin currently).
- It creates the __.dns meta-TLD__. Each `.dns` "TLD" belongs to just one DNSChain server: the one you're connected to.
- It's an HTTP server (and in the future, an HTTPS server)
- It lets you communicate directly with information in blockchains (read, and maybe even write!) from [JavaScript apps](http://okturtles.com)!
- At its core, it lets you connect to websites, and chat with your friends, and be safe from eavesdroppers and Big Brother-type entities. It gives you the gift of **authentication**.

It's also only about *600 lines of easy to understand CoffeeScript!* This means that even mere mortals can look at the code, and verify for themselves that it is safe to run on their systems.

### Simple and secure GPG key distribution<a name="GPG"/>

![Easily share your GPG key!](https://www.taoeffect.com/includes/images/twitter-gpg-s.jpg)

1. Use `namecoind` to [register](https://github.com/namecoin/wiki/wiki/Register-and-Configure-.bit-Domains) your identity in the `id/` [namespace](https://github.com/namecoin/wiki/wiki/Identity).
2. Use a DNSChain server that exposes its `.dns` meta-TLD through the traditional DNS, as shown in the screenshot.

It's always best to use your own server, of course. _Note: headers containing crypographic signatures will be sent soon!_

### Free SSL certificates become possible<a name="Free"/>

SSL certificates today [do not provide the security that they claim to provide](http://okturtles.com/other/dnsnmc_okturtles_overview.pdf). DNSChain replaces Certificate Authorities by providing a means for distributing public keys in a way that is secure from MITM attacks.

## How do I use it?<a name="Use"/>

No special software is required, just set your computer's DNS settings to use [one of the public DNSChain servers](#servers) (more secure to run your own though).

Then try the following:

- Visit [http://okturtles.bit](http://okturtles.bit)
- "What's the domain info for `okturtles.bit`?" [http://namecoin.dns/d/okturtles](http://namecoin.dns/d/okturtles)
- "Who is Greg and what is his GPG info?" [http://namecoin.dns/id/greg](http://namecoin.dns/id/greg)

__Don't want to change your DNS settings?__

As a convenience, the first DNSChain server's `.dns` meta-TLD can be accessed over the old-DNS by way of `dns.dnschain.net`, like so:

- "Who is Greg?" [http://dns.dnschain.net/id/greg](http://dns.dnschain.net/id/greg)

This means you can immediately being writing [JavaScript apps](http://okturtles.com) that query the blockchain. :)

__The '.dns' meta-TLD__

__.dns__ is a "meta-TLD". It is called so because unlike traditional TLDs, it is not meant to globally resolve to a specific IP. Rather, it is meant to resolve to a DNSChain server that *_you personally own and run_*.

When a DNSChain server sees a request to a `.dns` domain, it handles the request itself, looking it up in a blockchain stored on that same server. At the moment, DNSChain uses the Namecoin blockchain, but it easily be configured to use any blockchain.


### Free public DNSChain servers<a name="Free"/>

*DNSChain is meant to be run by individuals!*

Yes, you can use a public DNSChain server, but it's far better to use your own because it gives you more privacy, makes you more resistant to censorship, and provides you with a stronger guarantee that the responses you get haven't been tampered with by a malicious server.

Those who do not own their own server or VPS can use their friend's (as long as they trust that person). DNSChain servers will sign all of their responses, thus protecting your from MITM attacks. *(NOTE: signing is not yet implemented, but will be soon)*

You can, if you must, use a public DNSChain server. Simply [set your computer's DNS settings](https://startpage.com/do/search?q=how+to+change+DNS+settings) to one of these. Those marked *ENCRYPTED* require [dnscrypt-proxy](https://github.com/jedisct1/dnscrypt-proxy).

1. 192.184.93.146
2. [23.226.227.93](https://gist.github.com/taoeffect/8855230) *ENCRYPTED*
3. Yours here!

Tell us about yours by opening an issue (or any other means) and we'll list it here!

We'll list the public keys for these servers here as well when the signing of responses is implemented. Note that for *ENCRYPTED* servers you are already guaranteed the authenticity of responses.

## How do I run my own?<a name="Run"/>

Get yourself a Linux server (they come as cheap as $2/month), and then make sure you have the following software installed:

#### Requirements<a name="Requirements"/>

1. `nodejs` and `npm`
2. [coffee-script](https://github.com/jashkenas/coffee-script) (version 1.7.1+) - install via `npm install -g coffee-script`
3. `grunt-cli` - install via `npm install -g grunt-cli`
4. `namecoind` - [instructions](https://github.com/namecoin/wiki/wiki/Install-and-Configure-Namecoin)

#### Getting Started<a name="Getting"/>

1. Have `namecoind` run in the background _(we recommend running it with `systemd` and naming the unit file `namecoin.service`)_
2. Clone this repo _(NOTE: It's best to install DNSChain via `npm`! It will be published there soon!)_
3. Run `npm install` inside of the cloned repo. _(This won't be necessary when installing via `npm`)_
4. Run `sudo ./bin/dnschain` or `sudo grunt example`

DNSChain will fetch the RPC username and password out of Namecoin's configuration file.

Have a look at [config.coffee](src/lib/config.coffee), it should clear up your questions about all configuration-related matters (if you know CoffeeScript, and you really should, it's a fine language).

To get DNSChain running on a Linux server we recommend using `systemd`. A unit/service file [is included](scripts/dnschain.service) in the scripts folder (that you can copy and customize to your liking).

Developers will notice that while running `sudo grunt example`, grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

_(A nicer and more user-friendly "getting started" section is coming soon!)_

## Community & Contributing<a name="Community"/>

You can contribute however you would like!

Forums, an irc channel, etc. coming soon. For now feel free to open issues & pull requests, send an emails to hi at okturtles.com, and/or tweet [@DNSChain](https://twitter.com/dnschain).

__Style and Process__

To test and develop at the same time, simply run `sudo grunt example` and set your computer's DNS to use `127.0.0.1`. Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

## TODO<a name="TODO"/>

See TODOs in source, below is only a partial list.

- __BUG:__ Fix ANY resolution for .bit and .dns domains.
- sign response.
- Support command line arguments
    - `portmap` for `iptables` support.
    - `-v`
    - `-h`

## Release History<a name="Release"/>

_(Coming soon)_

## License<a name="License"/>

Copyright (c) 2013 Greg Slepak. Licensed under the BSD 3-Clause license.
