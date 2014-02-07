# DNSChain
<!-- # DNSChain [![Build Status](https://secure.travis-ci.org/okTurtles/dnschain.png?branch=master)](http://travis-ci.org/okTurtles/dnschain) -->

DNSChain (formerly DNSNMC), fixes HTTPS security by replacing certificate authorities with blockchain-technology, and more!

(This readme is under construction, but many parts have been filled out already! :)

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

1. `coffee-script` (1.7.1 or higher)
2. `node` and `npm`
3. `grunt-cli` (installed via `npm`)
4. `namecoind` (other blockchain networks easily supportable!)

## Getting Started for devs and sys admins

This section __to-be-finished__! For now I'll quickly note the basic idea, which is standard NodeJS development:

1. Clone this repo
2. Install `node` and `npm` using your system's package manager (on OS X, that would be Homebrew). Note that `npm` sometimes is bundled with `node`.
3. Run `npm install` inside of the cloned repo.

DNSChain expects `namecoind` to be running in the background, and will fetch the RPC username and password out of Namecoin's configuration file.

Have a look at [config.coffee](blob/master/src/lib/config.coffee), it should clear up your questions about all configuration-related matters (if you know CoffeeScript, and you should).

Then, you can start the development & demo server by running `sudo grunt example`. You can also run the `dnschain` binary in the bin folder.

To get DNSChain running on a Linux server we recommend using `systemd`. A unit/service file [is included](blob/master/scripts/dnschain.service) in the scripts folder (that you can copy and customize to your liking).

_(A nicer and more user-friendly "getting started" section is coming soon!)_

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
