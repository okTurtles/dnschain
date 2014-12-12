# DNSChain versus...

## Certificate Transparency

Google's Certificate Transparency proposal wants certificate authorities (CAs) to "make a note" all of the certificates that they issue into a log. [It does not protect against NSA spying and MITM attacks](http://blog.okturtles.com/2014/09/the-trouble-with-certificate-transparency/). Website owners are then asked to monitor these logs to see if their clients were hacked. Everyone must continue to pay the Certificate Authorities money for insecurity.

- __*Best case* scenario: mis-issuance detected _after_ damage has been done. The CA blames hackers.__

## DNSSEC

[DNSSEC](http://www.icann.org/en/about/learning/factsheets/dnssec-qaa-09oct08-en.htm) suggests a complicated mechanism to essentially re-create many of the same problems with X509 and CAs in DNS itself, by providing a chain of trust to untrustworthy entities. Its intended goal is to secure DNS and thereby assure clients that when they ask for apple.com, they are actually visiting apple.com. This proposal [does not protect against MITM attacks](http://www.thoughtcrime.org/blog/ssl-and-the-future-of-authenticity/). It suffers from extreme and unnecessary complexity, a systemic fault that's antithetical to secure systems.

- __See also: [why DNSSEC is considered harmful.](http://ianix.com/pub/dnssec-outages.html)__

## Convergence

In [their words](http://convergence.io/details.html), Convergence:

> ...is a secure replacement for the Certificate Authority System. Rather than employing a traditionally hard-coded list of immutable CAs, Convergence allows you to configure a dynamic set of Notaries which use network perspective to validate your communication.

In our words: Convergence is similar to having a `known_hosts` ssh key file for your browser, and comparing it against your friend’s file. It's not a terrible idea, however:

- It is not user friendly in the slightest. Users are asked to manage a list of notaries. This list of notaries is stored locally on the computer, or even the browser. Managing this list is not feasible for most users.
- It depends on group consensus, but this group of servers can be man-in-the-middle'd by a global adversary. What happens then? The blockchain does not have this problem because once a transaction makes its way into a block, that's that (the data cannot be tampered with).
- It does not provide MITM protection on first-visit.
- Waiting for group consensus means all connections have higher latency (slower page loads).

## Perspectives

[Perspectives](http://perspectives-project.org/) is very similar to Convergence and suffers from the same problems.

## Bitmessage

_Bitmessage is more appropriately compared against the unreleased [okTurtles browser extension](http://okturtles.org), which uses DNSChain._

[Bitmessage](https://bitmessage.org/wiki/Main_Page) belongs to the same family of software that okTurtles and DNSChain belong to, however it is also very different from them. Bitmessage focuses on providing anonymity to its users first and foremost. For reasons unknown to this author it was not designed to use the Namecoin blockchain, and instead uses its own (though there is nothing preventing integration between the two, and indeed work [has been done](https://bitmessage.org/forum/index.php?topic=2563.0) in this area). Bitmessage, however, has a few problems that software using DNSChain does not have:

- It does not work over existing websites or protocols (like email) and was not designed with this intention.
- To quote [the paper](http://okturtles.com/other/bitmessage.pdf): _"The difficulty of the proof‐of‐work should be proportional to the size of the message and should be set such that an average computer must expend an average of four minutes of work in order to send a typical message."_
- It requires constantly running a program in the background (and one that isn't feasible on most mobile devices).
- Messages take a long time to get to their destination because: _"Just like Bitcoin transactions and blocks, all users would receive all messages. They would be responsible for attempting to decode each message with each of their private keys to see whether the message is bound for them."_
