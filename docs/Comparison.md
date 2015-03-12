# DNSChain versus...

- [Certificate Transparency](<#certificate-transparency>)
- [DNSSEC](<#dnssec>)
- [Convergence](<#convergence>)
- [Perspectives](<#perspectives>)
- [TACK / HPKP](<#tack--hpkp>)
- ["Thin" or "Light" Clients](<#thin-clients--light-clients>)

### Certificate Transparency

Google's Certificate Transparency proposal wants certificate authorities (CAs) to "make a note" all of the certificates that they issue into a log. [It does not protect against NSA spying and MITM attacks](http://blog.okturtles.com/2014/09/the-trouble-with-certificate-transparency/). Website owners are then asked to monitor these logs to see if their clients were hacked. Everyone online still forced to trust the bad apple (the least trustworthy CA).

- __*Best case* scenario: mis-issuance detected _after_ damage has been done. The CA blames hackers.__

### DNSSEC

[DNSSEC](http://www.icann.org/en/about/learning/factsheets/dnssec-qaa-09oct08-en.htm) suggests a complicated mechanism to essentially re-create many of the same problems with X509 and CAs in DNS itself, by providing a chain of trust to untrustworthy entities. Its intended goal is to secure DNS and thereby assure clients that when they ask for apple.com, they are actually visiting apple.com. This proposal [does not protect against MITM attacks](http://www.thoughtcrime.org/blog/ssl-and-the-future-of-authenticity/). It suffers from extreme and unnecessary complexity, a systemic fault that's antithetical to secure systems.

- :page_facing_up: __[DNSSEC Outages](http://ianix.com/pub/dnssec-outages.html)__ (Scroll down to __"Miscellaneous"__ section)
- :page_facing_up: __[Against DNSSEC](http://sockpuppet.org/blog/2015/01/15/against-dnssec/)__

### Convergence

In [their words](http://convergence.io/details.html), Convergence:

> ...is a secure replacement for the Certificate Authority System. Rather than employing a traditionally hard-coded list of immutable CAs, Convergence allows you to configure a dynamic set of Notaries which use network perspective to validate your communication.

In our words: Convergence is similar to having a `known_hosts` ssh key file for your browser, and comparing it against your friend’s file. It's not a terrible idea, however:

- It is not very user friendly. Users are asked to manage a list of notaries. This list of notaries is stored locally on the computer, or even the browser. Managing this list is not feasible for most users.
- It's not clear how well it protects (or can protect) if some notaries haven't yet cached the latest SSL certificate for a particular website.
- It does not provide MITM protection on first-visit.
- Waiting for group consensus means all connections have higher latency (slower page loads).
- Both Convergence and Perspectives (see below) results in you sharing every website you visit with random third-parties. With DNSChain, if privacy is a concern, you can run your own server and only rely on it: it will provide both better performance and superior security.

### Perspectives

[Perspectives](http://perspectives-project.org/) is very similar to Convergence and suffers from the same problems. It allows "no reply" from notaries, making it not useful in a MITM attack.

### TACK / HPKP

Both [TACK](https://lwn.net/Articles/499134/) and [HPKP](https://developer.mozilla.org/en-US/docs/Web/Security/Public_Key_Pinning) are mechanisms for doing [public key pinning](https://en.wikipedia.org/wiki/Transport_Layer_Security#Certificate_pinning) for individual websites.

These mechanisms are similar to how SSH uses a `known_hosts` file to store the fingerprints of public keys it encounters on a "Trust-On-First-Use" ("TOFU") basis.

The problem with these mechanisms is:

- They don't protect on first visit.
- They break websites when the public key needs to legitimately change.
- In the case of TACK, the TACK public key needs to change very frequently ([at least every 30 days](https://lwn.net/Articles/499134/)). This defeats the purpose of pinning, as a MITM does not need to wait long before they can present a fraudulent key that the user has no way to know is legitimate.
- These mechanisms assume that client software has its current time set properly, and they break when that's not true.

While DNSChain does use public key pinning, it doesn't have these problems because there is only one pin that is ever required: the pin to DNSChain itself, which is easily verified once only at setup.

### Thin Clients / Light Clients

[Thin Clients](https://en.bitcoin.it/wiki/Thin_Client_Security) are actually really great! They offer a way to access blockchain data in an extremely efficient and lightweight manner while maintaining a level of security that is almost as good as that provided by a full node (and in the case of "SPV+" or "UTXO" type clients, possibly equivalent, depending on how it's implemented).

Some concerns with Thin Clients include:

- Their non-existence. As soon as thin clients that can be used to do arbitrary key/value lookups come about, DNSChain plans to support them!
- Over-reliance on SPV(+) clients can lead to a centralization of the entire network as fewer full nodes are being operated. Ultimately, the network is only as healthy as the number of full nodes there are, and full nodes can only reasonably be run on a server. *(DNSChain helps make the security of full nodes accessible today at the cost of having to trust the DNSChain servers you're talking to. If that's a concern, clients can increase the number of DNSChain servers they talk to.)*
- Some platforms do not support Thin Clients well. Examples include:
    * Apple's iOS does not allow you to download and run a thin client (or any server) in the background that other apps can talk to. Therefore any app that wanted to talk to the blockchain would need to bundle its own thin client. On mobile devices, it is far more practical for apps to talk to DNSChain.
    * Thin clients that perform DNS could result in a poor user experience on mobile devices if they've been offline for a prolonged period of time. They would need to wait until the thin client synced up with the network before it could be used reliably. DNSChain, on the other hand, provides instant access to the blockchain.
- As mentioned previously, there are different kinds of thin clients, some of which provide a better user experience and security than others. It will be a while before we see high quality ones that can be used for DNS in the wild.

That all said, you should support thin client development as they are a very powerful and useful tool for effectively improving online security.

When they *do* start popping up, they can choose whether to directly implement the [Openname Resolver Specification](https://github.com/openname/openname-specifications/blob/master/resolvers.md) or use DNSChain as "middleware" so that apps have a simple and standard interface for communicating with the blockchain.

Useful resources on thin clients:

- :page_facing_up: __[Bitcoin wiki: Thin Client Security](https://en.bitcoin.it/wiki/Thin_Client_Security)__
- :page_facing_up: __[Various types of thin clients Namecoin is exploring](https://github.com/hlandau/ncdocs/blob/master/stateofnamecoin.md)__
- :page_facing_up: __[Namecoin blog: Lightweight Resolvers](http://blog.namecoin.org/post/109811339625/lightweight-resolvers)__
