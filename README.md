# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain fixes HTTPS security by replacing certificate authorities with blockchain-technology, and more!

## How to start using DNSChain _\*right now\*!_

Just set your DNS settings to 192.184.93.146.

Or run me on your own server! (This is best of course.)

_(More coming soon)_

## Requirements

1. coffee-script 1.7.1 (or higher)
2. node
3. npm

## Getting Started
<!-- Install the module with: `npm install dnschain`

```javascript
var dnschain = require('dnschain');
dnschain.awesome(); // "awesome"
```
 -->
## Documentation
_(Coming soon)_

## Examples
_(Coming soon)_

## Contributing

You can contribute however you would like, but we recommend first chatting with the dev team about your ideas (forums coming soon, for now send an email to hi at okturtles.com, or tweet [@DNSChain](https://twitter.com/dnschain)). This will help minimize wasted efforts.

### Style and Process

To test and develop at the same time, simply run `sudo grunt example` and set your computer's DNS to use `127.0.0.1`. Grunt will automatically lint your code to the style used in this project, and when files are saved it will automatically re-load and restart the server (as long as you're editing code under `src/lib`).

## TODO

See TODOs in source, below is only a partial list.

- __BUG:__ Fix ANY resolution for .bit and .dns domains.
- sign response.
- Support command line arguments
    - `portmap` for `iptables` support.
    - `-v`
    - `-h`

## Release History
_(Nothing yet)_

## License
Copyright (c) 2013 Greg Slepak. Licensed under the BSD 3-Clause license.
