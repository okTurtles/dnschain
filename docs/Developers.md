# Developer's Guide

- [Securing Your Apps With DNSChain](<#securing-your-apps-with-dnschain>)
- [Contributing to DNSChain development](<#contributing-to-dnschain-development>)
- [Adding support for your favorite blockchain](<#adding-support-for-your-favorite-blockchain>)
- [Running Tests](<#running-tests>)

#### Securing Your Apps With DNSChain

Developers of secure communications applications looking to improve the usability and security of their apps should familiarizing themselves with the following documentation:

- [How to use DNSChain](How-do-I-use-it.md)
- [How to run a DNSChain server](How-do-I-run-my-own.md)
- [RESTful API specification](What-is-it.md#API)

Developer-friendly libraries in various languages for interacting with DNSChain in a MITM-proof manner are coming:

- [DNSChain for Python](https://github.com/okTurtles/pydnschain)
- _Your favorite language here!_

<a name="Working"/>
#### Contributing to DNSChain development

Make sure you did everything in the [requirements](How-do-I-run-my-own.md#Requirements) and then play with these commands from your clone of the DNSChain repository:

- `sudo grunt example` _(runs on privileged ports by default)_
- `grunt example` _(runs on non-privileged ports by default)_

Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

When forking DNSChain: work on feature branches, not `master`, then submit a PR.

#### Adding support for your favorite blockchain

1. Copy the file `src/lib/blockchain.coffee` and place it in `src/lib/blockchains`.
2. Rename it after your blockchain (no spaces).
3. Edit it by following the advice offered by the comments. Look at how the other files in the `blockchains` folder have done it.

That's it! Send us a pull request and we'll be happy to include support for your favorite blockchain. :)

#### Running Tests

From within the DNSChain repo, make sure you've run `npm install`, and then:

    npm test
