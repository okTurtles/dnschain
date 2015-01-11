# Developer's Guide

_This section will be expanded. We invite you to join in and help us improve this documentation! :smile:_

## Securing Your Apps With DNSChain

Developers of secure communications applications looking to improve the usability and security of their apps should familiarizing themselves with the following documentation:

- [How to use DNSChain](How-do-I-use-it.md)
- [How to run a DNSChain server](How-do-I-run-my-own.md)
- [RESTful API specification](What-is-it.md#metaTLD)

Developer-friendly libraries in various languages for interacting with DNSChain in a MITM-proof manner are coming:

- [DNSChain for Python](https://github.com/okTurtles/pydnschain)
- _Your favorite language here!_

<a name="Working"/>
## Contributing to DNSChain development

Make sure you did everything in the [requirements](How-do-I-run-my-own.md#Requirements) and then play with these commands from your clone of the DNSChain repository:

- `sudo grunt example` _(runs on privileged ports by default)_
- `grunt example` _(runs on non-privileged ports by default)_

Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

When forking DNSChain: work on feature branches, not `master`, then submit a PR.

## Running Tests

    npm install
    npm test
