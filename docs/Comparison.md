# DNSChain versus...

- [Certificate Transparency](<#certificate-transparency>)
- [DNSSEC](<#dnssec>)
- [Convergence](<#convergence>)
- [Perspectives](<#perspectives>)
- [TACK / HPKP](<#tack--hpkp>)
- ["Thin" or "Light" Clients](<#thin-clients--light-clients>)

### Certificate Transparency

Google's Certificate Transparency proposal wants certificate authorities (CAs) to publicly log all of the certificates that they issue. [It does not protect against NSA spying and MITM attacks](https://blog.okturtles.com/2015/03/certificate-transparency-on-blockchains/). Website owners are then asked to monitor these logs to see if their clients were hacked. Everyone online is still forced to trust the bad apple (the least trustworthy CA).

- __*Best case* scenario: mis-issuance detected _after_ damage has been done. The CA blames hackers.__

### DNSSEC

[DNSSEC](http://www.icann.org/en/about/learning/factsheets/dnssec-qaa-09oct08-en.htm) suggests a complicated mechanism to essentially re-create many of the same problems with X509 and CAs in DNS itself, by providing a chain of trust to untrustworthy entities. Its intended goal is to secure DNS and thereby assure clients that when they ask for apple.com, they are actually visiting apple.com. This proposal [does not protect against MITM attacks](http://www.thoughtcrime.org/blog/ssl-and-the-future-of-authenticity/). It suffers from extreme and unnecessary complexity, a systemic fault that's antithetical to secure systems.

- :page_facing_up: __[DNSSEC Outages](http://ianix.com/pub/dnssec-outages.html)__ (Scroll down to __"Miscellaneous"__ section)
- :page_facing_up: __[Against DNSSEC](http://sockpuppet.org/blog/2015/01/15/against-dnssec/)__

### Convergence

In [their words](http://convergence.io/details.html), Convergence:

> ...is a secure replacement for the Certificate Authority System. Rather than employing a traditionally hard-coded list of immutable CAs, Convergence allows you to configure a dynamic set of Notaries which use network perspective to validate your communication.

In our words: Convergence is similar to having a `known_hosts` ssh key file for your browser, and comparing it against your friend’s file. It's not a terrible idea, however:

- It does not protect you if the MITM is sitting in front of the server you are visiting. Notaries would see exactly the same key that you see (the one that belongs to the MITM).
- It introduces high latency on first visit in order for group consensus to form.


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

[Thin Clients](https://en.bitcoin.it/wiki/Thin_Client_Security) are [very important](https://blog.okturtles.com/2015/06/proof-of-transition-new-thin-client-technique-for-blockchains/) and we are working to define and integrate [arbitrary thin client techniques](https://blog.okturtles.com/2015/06/proof-of-transition-new-thin-client-technique-for-blockchains/) into DNSChain.

So far most thin clients use Simplified Payment Verification (SPV) as their verification method. SPV may not work well in all situations, however:

- Apple's iOS does not allow you to download and run servers in the background that other apps can talk to. This is an issue for SPV, which needs to always remain synced with the network.
- SPV can result in a slower user experience on mobile devices. If the device has been off for a while, users would need to wait until the thin client syncs back up with the network before before accessing online resources.

[Proof-of-Transition](https://blog.okturtles.com/2015/06/proof-of-transition-new-thin-client-technique-for-blockchains/) is a thin client technique that may work better on iOS.

It's important to remember that while thin clients are very important, blockchains are only as healthy as the number of full nodes there are, and full nodes can only reasonably be run on a server. DNSChain helps encourage the wider deployment of full nodes by making them accessible over a single protocol.

Useful resources on thin clients:

- :page_facing_up: __[Proof of Transition: New Thin Client Technique for Blockchains](https://blog.okturtles.com/2015/06/proof-of-transition-new-thin-client-technique-for-blockchains/)__
- :page_facing_up: __[Bitcoin wiki: Thin Client Security](https://en.bitcoin.it/wiki/Thin_Client_Security)__
- :page_facing_up: __[Various types of thin clients Namecoin is exploring](https://github.com/hlandau/ncdocs/blob/master/stateofnamecoin.md)__
- :page_facing_up: __[Namecoin blog: Lightweight Resolvers](http://blog.namecoin.org/post/109811339625/lightweight-resolvers)__
