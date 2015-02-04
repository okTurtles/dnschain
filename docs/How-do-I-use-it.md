# How do I use DNSChain?

No special software is required, just set your computer's DNS settings to use [one of the public DNSChain servers](#Servers) (more secure to run your own though).

Then try the following:

- Visit [http://okturtles.bit](http://okturtles.bit)
- "What's the domain info for `okturtles.bit`?" [http://namecoin.dns/d/okturtles](http://namecoin.dns/d/okturtles)
- "Who is Greg and what is his GPG info?" [http://namecoin.dns/id/greg](http://namecoin.dns/id/greg)

__Don't want to change your DNS settings?__

DNSChain's [`.dns` metaTLD](What-is-it.md#metaTLD) can be accessed over traditional DNS. For example, [okTurtles](http://okturtles.org) exposes their public DNSChain server at `dns.dnschain.net`, like so:

- "Who is Greg?" [http://dns.dnschain.net/id/greg](http://dns.dnschain.net/id/greg)

This means you can immediately begin writing [JavaScript apps](http://okturtles.com) that query the blockchain. :)

| **:exclamation:** The public fingerprint of the DNSChain server must be pinned in client software for the queries to be [MITM-proof](https://github.com/okTurtles/dnschain/blob/master/docs/What-is-it.md#MITMProof)! |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

<a name="Servers"/></a>
## Free public DNSChain servers

*DNSChain is meant to be run by individuals!*

Yes, you can use a public DNSChain server, but it's far better to use your own because it gives you more privacy, makes you more resistant to censorship, and provides you with a stronger guarantee that the responses you get haven't been tampered with by a malicious server.

Those who do not own their own server or VPS can use their friend's (as long as they trust that person). DNSChain servers will sign all of their responses, thus protecting your from MITM attacks. *(NOTE: signing is not yet implemented, but will be soon)*

You can, if you must, use a public DNSChain server. Simply [set your computer's DNS settings](https://startpage.com/do/search?q=how+to+change+DNS+settings) to one of these. Note that some of the servers must be used with [dnscrypt-proxy](https://github.com/jedisct1/dnscrypt-proxy).

|                          IP or DNSCrypt provider                           |        [DNSCrypt](http://dnscrypt.org/) Supported?         | Logs |    Location    |                          Owner                          |     Notes      |
|----------------------------------------------------------------------------|------------------------------------------------------------|------|----------------|---------------------------------------------------------|----------------|
| 192.184.93.146 (aka [d/okturtles](http://dns.dnschain.net/d/okturtles))    | N/A                                                        | No   | Atlanta, GA    | [id/greg](http://dns.dnschain.net/id/greg)              |                |
| 54.85.5.167 (aka [name.thwg.org](name.thwg.org))                           | N/A                                                        | No   | USA            | [id/wozz](http://dns.dnschain.net/id/wozz)              |                |
| [2.dnscrypt-cert.okturtles.com](https://gist.github.com/taoeffect/8855230) | [Required Info](https://gist.github.com/taoeffect/8855230) | No   | Atlanta, GA    | [id/greg](http://dns.dnschain.net/id/greg)              |                |
| [2.dnscrypt-cert.soltysiak.com](http://dc1.soltysiak.com)                  | [Required Info](http://dc1.soltysiak.com)                  | No   | Poznan, Poland | [@maciejsoltysiak](https://twitter.com/maciejsoltysiak) | IPv6 available |

Tell us about yours by opening an issue (or any other means) and we'll list it here!

Responses can be sured over HTTPS by pinning SSL certificates, and over DNS by using DNSCrypt.

<a name="Registering"/></a>
## Registering blockchain domains and identities

[:book: Registering blockchain domains and identities](dot-bit-Domains-and-Identities.md)

You can register and use `.bit` domain names from Namecoin, and there are more blockchain based domains coming soon. Read about and secure your digital identity also, and access it using DNSChain.
