# What is DNSChain?

DNSChain makes it possible to be certain that you're communicating with who you want to communicate with, and connecting to the sites that you
want to connect to, *without anyone secretly listening in on your conversations in between.*

#### Table of Contents

- [DNSChain replaces X.509 PKI with the blockchain](#DNSChain)
- [MITM-proof'ed Internet connections](#MITMProof)
- [Simple and secure GPG key distribution](#GPG)
- [Free SSL certificates become possible](#Free)
- [Prevents DDoS attacks](#DDoS)
- [Certificate revocation that actually works](#Revocation)
- [DNS-based censorship circumvention](#Censorship)
- [RESTful API via `.dns` metaTLD](#metaTLD)

<a name="DNSChain"></a>
### DNSChain replaces X.509 PKI with the blockchain

[X.509](https://en.wikipedia.org/wiki/X.509) makes and breaks today's Internet security. It's what makes your browser
think ["The connection to this website is secure"](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/) when [it's not](http://okturtles.com/#not-secure).
It's what we have to get rid of, and DNSChain provides a scalable, distributed, and decentralized replacement that doesn't depend on untrustworthy
third-parties.

<a name="MITMProof"></a>
### MITM-proof *all* Internet connections

> **"One Pin To Rule Them All"**

Connections between DNSChain and the clients it serves are **MITM-proofed** through
the well-known technique of
**[public-key pinning](https://en.wikipedia.org/wiki/Transport_Layer_Security#Certificate_pinning)**. The key difference with DNSChain is that a single pin
is all that's required to MITM-proof *all other Internet connections:*

- DNSChain works side-by-side with full blockchain nodes that run
on the same server.
- Websites and individuals store their public key in a blockchain (DNSChain
supports several), and from then on that
key becomes MITM-proof.
- The latest and most correct key is sent to clients over the secure
channel between DNSChain and its clients. They are then able to establish further MITM-proof connections with the owner(s) of those key(s).

__:tv: Watch: [Securing online communications with the blockchain](https://www.youtube.com/watch?v=Qy1x3Ud8LCI)__

<a name="GPG"></a>
### Simple and secure GPG key distribution

The blockchain is a secure, decentralized database. The information
stored in it can be read at any location around the world, and DNSChain
provides easy access to it via [a blockchain agnostic API](https://github.com/openname/openname-specifications/blob/master/resolvers.md).

![Easily share your GPG key!](https://www.taoeffect.com/includes/images/twitter-gpg-s.jpg)

Any DNSChain server can be used to retrieve the same information. Storing information in the blockchain is a bit more difficult, but with time, this too will become simple.

<a name="Free"></a>
### Free SSL certificates become possible

Certificates issued by Certificate Authorities (CAs) can be undermined by thousands of entities
(other CAs, their employees, governments, and hackers).

It does not matter whether you pay $300 per year for the fancy green bar in a browser or $0/year, your website's visitors [can still be attacked](http://okturtles.com/#not-secure).

Together, DNSChain and the blockchains it works with replace CAs by providing a means for distributing public keys in a way that is secure from MITM attacks. Because of this, free self-signed certificates can be used. Unlike
CAs, users are given actual reason to trust DNSChain: they choose the server
they trust (their own, or a friend's).

<a name="DDoS"></a>
### Prevents DDoS attacks

Unlike traditional DNS servers, DNSChain encourages widespread deployment of the server (ideally, "one for every group of friends").
This distributed, flat topology eliminates the need for open resolvers by making it practical to limit clients to a small, trusted set.
Additionally, whereas traditional DNS resolvers must query other DNS servers to answer queries, blockchain-based DNS resolvers have no
such requirement because *all* of the data necessary to answer queries is stored locally on the server.

Another DoS attack relates to the centralized manner in which today's SSL certificates are checked for revocation:

<a name="Revocation"></a>
### Certificate revocation that actually works

The wonderful thing about blockchains is that they *have no conception of revocation* because they do not need one. Instead, the most recent value for any particular key in a blockchain is the most accurate and up-to-date value.

TODO: [Explain OCSP](https://news.ycombinator.com/item?id=7556909) and DoS plays a role in it.

<a name="Censorship"></a>
### DNS-based censorship circumvention

The developers of [Unblock.us.org](https://github.com/SGrondin/unblock.us.org) and DNSChain are teaming up to bring the anti-censorship features of Unblock.us into DNSChain. Each project benefits from the other: DNSChain ensures MITM-free communication and Unblock.us ensures that the communication passes through firewalls.

The Unblock.us feature is optional and is up to the server administrator to enable and configure to their needs. It uses MITM to defeat censorship at its own game.

Unblock.us works by hijacking the DNS lookups for the domains on a list defined by the server administrator. The server then accepts all HTTP and HTTPS traffic addressed to those domains and forwards it intelligently. Even though it can't decrypt SSL traffic, it can still forward it. It's as fast as a VPN (unlike Tor) and ONLY tunnels the traffic to those domains, meaning that it doesn't affect other online activites (unlike VPNs and Tor) and isn't costly in server bandwidth. Finally, there's no software to install, only DNS settings to change. It has been confirmed to work in Turkey, UK, Kuwait, UAE and many additional Middle Eastern countries.

For now, Deep Packet Inspection techniques used in Pakistan and China can still beat Unblock.us, but the next version will address that issue using a technique called [Host Tunneling](http://unblock.us.org/?p=61). Short of cutting entire countries off the internet, DNSChain/Unblock.us will be able to get through.

<a name="metaTLD"></a>
### The `.dns` metaTLD

__`.dns`__ is [a meta-TLD](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/) because unlike traditional TLDs, it is not meant to globally resolve to a specific IP. Rather, it is meant to resolve to a DNSChain server that *_you personally own and run_*.

It bears emphasizing that *you cannot register a meta-TLD because you already own them!*

When a DNSChain server sees a request to a `.dns` domain, it handles the request itself, looking it up in a blockchain stored on that same server. At the moment, DNSChain uses the Namecoin blockchain, but it can easily be configured to use any blockchain.

**:page_facing_up: [Introducing the dotDNS metaTLD](http://blog.okturtles.com/2014/02/introducing-the-dotdns-metatld/)**

##### RESTful API

Openname and okTurtles are partnering to develop a RESTful API with DNSChain being the reference resolver that supporting it. This API is currently in development. You can watch its progress here:

**:page_facing_up: [Openname Resolver Specification](https://github.com/openname/openname-specifications/blob/master/resolvers.md)**
