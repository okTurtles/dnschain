# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain fixes HTTPS security by replacing certificate authorities with blockchain-technology, and more!

## How to start using DNSChain _\*right now\*!_

Set your DNS settings to [one of the public DNSChain servers](#servers). Free [encrypted DNS](https://gist.github.com/taoeffect/8855230) supported too!

Then try visiting some interesting domains:

- Visit [http://okturtles.bit](http://okturtles.bit)
- "What's the domain info for `okturtles.bit`?" [http://namecoin.dns/d/okturtles](http://namecoin.dns/d/okturtles)
- "Who's Greg?" [http://namecoin.dns/id/greg](http://namecoin.dns/id/greg)

__Remember, DNSChain is meant to be run by *you!*__

Only use a public server if you absolutely must!

#### Too lazy to change your DNS settings?

Or don't know how and too lazy to [Startpage it](https://startpage.com/do/search?q=how+to+change+DNS+settings)? :P

Some of this info you can get just by using `dns.dnschain.net`, like this:

- "Who's Greg?" [http://dns.dnschain.net/id/greg](http://dns.dnschain.net/id/greg)

Of course, doing that doesn't give you the guarantee of an authentic answer that you'd otherwise get by running your own DNSChain server. (Note, DNSChain is still under development, and signed headers aren't sent yet).

<a name="servers"></a>
## List of public DNSChain servers

1. 192.184.93.146
2. [23.226.227.93 (dnscrypt-only!)](https://gist.github.com/taoeffect/8855230)
3. Yours here!

Tell us about yours by opening an issue and we'll list it here!

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
