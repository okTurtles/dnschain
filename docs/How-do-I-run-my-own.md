# How do I run my own DNSChain Server?

| **See Also: [Mike's Guide to Installing Namecoin, DNSChain, and PowerDNS on Debian Wheezy](http://mikeward.net/how-to-setup-a-blockchain-dns-server-with-dnschain/)** |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------|

- [Requirements](#Requirements)
- [Getting Started](#Getting)
- [Configuration](#Configuration)
- [Working with the source](#Working)
- [Example Server Setup](#Example)

Get yourself a Linux server (they come as cheap as $2/month), and then make sure you have the following software installed:

<a name="Requirements"/>
## Requirements

1. `nodejs` and `npm` - We recommend using a package manager to install them.
2. [coffee-script](https://github.com/jashkenas/coffee-script) (version 1.7.1+) - install via `npm install -g coffee-script`
3. `grunt-cli` - install via `npm install -g grunt-cli`, provides the `grunt` command.
4. `namecoind`

<!--5. `libgmp` - needed by Mozilla's [jwcrypto](https://github.com/mozilla/jwcrypto), install using `apt-get install libgmp-dev` (Debian) or `brew install gmp` (OS X).

DNSChain __does not use the NodeJS crypto module__ for generating signed headers because that module uses `OpenSSL` (which is considered harmful [1](http://www.peereboom.us/assl/assl/html/openssl.html)[2](https://www.openssl.org/news/vulnerabilities.html)). Instead, Mozilla's [jwcrypto](https://github.com/mozilla/jwcrypto) is used.-->

<a name="Getting"/>
## Getting Started

1. Install DNSChain using: `npm install -g dnschain` (you may need to put `sudo` in front of that).
2. Run `namecoind` in the background. You can use `systemd` and create a `namecoin.service` file for it based off of [dnschain.service](<../scripts/dnschain.service>).
3. If an update is released, update your copy using `npm update -g dnschain`.

Test DNSChain by simply running `dnschain` from the command line (developers [see here](#Working)). Have a look at the configuration section below, and when you're ready, run it in the background as a daemon. As a convenience, DNSChain [comes with a `systemd` unit file](<../scripts/dnschain.service>) that you can use to run it.

**:page_facing_up: [Mike's Guide to Installing Namecoin, DNSChain, and PowerDNS on Debian Wheezy](http://mikeward.net/how-to-setup-a-blockchain-dns-server-with-dnschain/)**

<a name="Configuration"/>
## Configuration

| **:exclamation: Have a look at [config.coffee](<../src/lib/config.coffee>) to see all configuration options and defaults!** |
|-----------------------------------------------------------------------------------------------------------------------------|

DNSChain uses the wonderful [`nconf` module](https://github.com/flatiron/nconf) for all of its configuration purposes. This means that you can configure it using files, command line arguments, and environment variables.

There are two configurations to be aware of (both loaded using `nconf`): DNSChain's, and `namecoind`'s:

- `dnschain.conf` locations (in order of preference):
    - `$HOME/.dnschain.conf`
    - `$HOME/.dnschain/dnschain.conf`
    - `/etc/dnschain/dnschain.conf`
- `namecoin.conf` locations (in order of preference):
    - `$HOME/.namecoin/namecoin.conf`

DNSChain will fetch the RPC username and password out of Namecoin's configuration file if it can find it. If it can't, you'll either need to fix that, or provide `rpcuser`, `rpcpassword`, etc. to it via command line arguments or environment variables.

The format of the configuration file is similar to INI, and is parsed by the NodeJS [`properties` module](https://github.com/gagle/node-properties) (in tandem with `nconf`). Here's an example of a possible `dnschain.conf`:

    [log]
    level=info
    
    [dns]
    port = 5333
    # no quotes around IP
    oldDNS.address = 8.8.8.8
    
    # disable traditional DNS resolution (default is NATIVE_DNS)
    oldDNSMethod = NO_OLD_DNS
    
    [http]
    port=8088
    tlsPort=4443

<a name="Example"/>
## Example Server Setup

As a guide we have an example server setup using Debian 7 and PowerDNS, along with a Namecoin node. This setup will resolve `.bit` domain names and should serve as an example which can be used with other blockchains.

[Example Server Setup](example-server-setup.md)