# DNSChain

There is a problem with how the Internet works today:

- HTTPS [is not secure](http://okturtles.com/#not-secure). Like most "secure" communications protocols,
  it is susceptible to undetectable public-key substitution MITM-attacks (example: [Apple iMessages](https://www.taoeffect.com/blog/2014/11/update-on-imessages-security/)).
- Netizens do not own their online identities. We either borrow them from
  companies like twitter, or rent then from organizations like ICANN.

These problems arise out of two core Internet protocols:
[DNS](https://en.wikipedia.org/wiki/Domain_Name_System) and [X.509](https://en.wikipedia.org/wiki/X.509).

DNSChain offers a free and secure decentralized alternative while remaining backwards compatible
with traditional DNS.
It compares favorably to [the alternatives](docs/Comparison.md), and provides the following features:
︎

|                                                                        |      DNSChain      | X.509 PKI [with or without Certificate Transparency][ct] |
|------------------------------------------------------------------------|--------------------|----------------------------------------------------------|
| __MITM-proof'ed [Internet connections][mitm]__                         | :white_check_mark: | :x:                                                      |
| __Secure and simple [GPG key distribution][gpg]__                      | :white_check_mark: | :x:                                                      |
| __Free and [actually-secure][free] SSL certificates__                  | :white_check_mark: | :x:                                                      |
| __Stops many [denial-of-service attacks][dos]__                        | :white_check_mark: | :x:                                                      |
| __Certificate revocation [that actually works][rev]__                  | :white_check_mark: | :x:                                                      |
| __DNS-based [censorship circumvention][cens]__                         | :white_check_mark: | :x:                                                      |
| __Prevents [domain theft][] ("seizures")__                             | :white_check_mark: | :x:                                                      |
| __Access blockchain-based [domains like `.bit`, `.p2p`, `.eth`][use]__ | :white_check_mark: | :x:                                                      |
| __RESTful API to blockchain via [.dns metaTLD][meta]__                 | :white_check_mark: | :x:                                                      |

[ct]: https://blog.okturtles.com/2014/09/the-trouble-with-certificate-transparency/
[mitm]: docs/What-is-it.md#MITMProof
[gpg]: docs/What-is-it.md#GPG
[free]: docs/What-is-it.md#Free
[dos]: docs/What-is-it.md#DDoS
[rev]: docs/What-is-it.md#Revocation
[cens]: docs/What-is-it.md#Censorship
[domain theft]: https://www.techdirt.com/articles/20141006/02561228743/5000-domains-seized-based-sealed-court-filing-confused-domain-owners-have-no-idea-why.shtml
[use]: docs/How-do-I-use-it.md
[meta]: docs/What-is-it.md#metaTLD

<a name="Documentation"></a>
## Documentation

<a name="What"></a>
### [:book: What is it?](docs/What-is-it.md)

- DNSChain replaces X.509 PKI with the blockchain
- MITM-proof authentication
- Simple and secure GPG key distribution
- Free SSL certificates become possible
- Prevents DDoS attacks
- Certificate revocation that actually works
- DNS-based censorship circumvention

<a name="Use"></a>
### [:book: Using DNSChain](docs/How-do-I-use-it.md)

- Free public DNSChain servers
- Access blockchain domains like `okturtles.bit`
- Registering blockchain domains and identities
- Encrypt communications end-to-end without relying on untrustworthy third-parties
- Unblock censored websites *(coming soon!)*
- And more!

<a name="Run"></a>
### [:book: Running your own DNSChain server](docs/How-do-I-run-my-own.md)

- Requirements
- Getting Started
- Configuration
- Guide: Setting up a DNSChain server with Namecoin and PowerDNS
- *Coming Soon: securing HTTPS websites with DNSChain.*

<a name="Developers"></a>
### [:book: Developers](docs/Developers.md)

- Securing Your Apps With DNSChain
- Contributing to DNSChain development
- Running Tests

<a name="Community"></a>
## Community

- [Forums](https://forums.okturtles.com)
- [@DNSChain](https://twitter.com/dnschain) + [@okTurtles](https://twitter.com/okTurtles)
- [![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/okTurtles/dnschain)

<a name="Resources"></a>
## Other Resources

__:tv: Watch__

- [okTurtles + DNSChain Demo at SOUPS 2014 EFF CUP](https://vimeo.com/100433057)
- [SF Bitcoin Meetup: Securing online communications with the blockchain](https://www.youtube.com/watch?v=Qy1x3Ud8LCI)
- [SF Bitcoin Developers Meetup: Deep Dive into Namecoin and DNSChain](https://www.youtube.com/watch?v=wUiMIy9urTA)

__:speaker: Listen__

- [P2P Connects Us Podcast on DNSChain](http://letstalkbitcoin.com/blog/post/p2p-connects-us-episode-four)
- [Beyond Bitcoin Hangouts with Bitshares crew on DNSChain](https://soundcloud.com/beyond-bitcoin-hangouts/beyond-bitcoin-hangout-greg-slepak-dnschain-2014-10-24)
- [Katherine Albrecht's privacy-focused radio show](http://www.katherinealbrecht.com/show-archives/2014/06/19/)

__:page_facing_up: Read__

- Engadget: [New web service prevents spies from easily intercepting your data](http://www.engadget.com/2014/09/29/okturtles/)
- Let's Talk Bitcoin: [Security in Decentralized Domain Name Systems](http://letstalkbitcoin.com/blog/post/security-in-decentralized-domain-name-systems)
- [An intro to DNSChain: Low-trust access to definitive data sources](http://simondlr.com/post/94988956673/an-intro-to-dnschain-low-trust-access-to)
- [How to setup a blockchain DNS server with DNSChain](docs/setting-up-dnschain-namecoin-powerdns-server.md)
- [The Trouble with Certificate Transparency](https://blog.okturtles.com/2014/09/the-trouble-with-certificate-transparency/)
- [Introducing the dotDNS metaTLD](https://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/)
- [DNSChain versus...](docs/Comparison.md)

_Have a link? [Let us know](https://twitter.com/dnschain)!_

<a name="Contributors"></a>
## Contributors

_Approximate chronological order._

- [Greg Slepak](https://twitter.com/taoeffect) (Original author and current maintainer)
- [Simon Grondin](https://github.com/SGrondin) (Unblock feature: DNS-based censorship circumvention)
- [Matthieu Rakotojaona](https://otokar.looc2011.eu/) (DANE/TLSA contributions and misc. fixes)
- [TJ Fontaine](https://github.com/tjfontaine) (For `native-dns`, `native-dns-packet` modules and related projects)
- [Za Wilgustus](https://twitter.com/ZancasDeArana) (For [pydnschain](https://github.com/okTurtles/pydnschain) contributions)
- [Cayman Nava](https://github.com/WeMeetAgain) (Ethereum support, api.icann.dns, and core developer)
- [Vignesh Anand](https://github.com/vegetableman) (Front-end + back-end for DNSChain admin interface)
- [Mike Ward](https://twitter.com/bocamike) (Documentation)
- [Dionysis Zindros](https://github.com/dionyziz) ([pydnschain](https://github.com/okTurtles/pydnschain) work)
- [Chara Podimata](https://www.linkedin.com/in/charapodimata) ([pydnschain](https://github.com/okTurtles/pydnschain) work)
- [Konstantinos Lolos](https://www.linkedin.com/in/kostislolos) ([pydnschain](https://github.com/okTurtles/pydnschain) work)
- *Your name & link of choice here!*

<a name="Release"></a>
## Release History

###### 0.2.5 - July 10, 2014

- Fixed `.bit` resolution bug introduced in `0.2.4`

###### 0.2.4 - July 10, 2014

- Fixed installation issue caused by `json-rpc2`
- Fixed exception (issue #20)
- Prevented possible DoS on in certain server setup where DNSChain
  is combined with another DNS server

###### [:book: Older version notes](HISTORY.md)

Copyright (c) okTurtles Foundation. Licensed under [MPL-2.0 license](http://mozilla.org/MPL/2.0/).
