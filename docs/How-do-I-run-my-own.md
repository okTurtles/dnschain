# How do I run my own DNSChain Server?

- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Guide: Setting up DNSChain + Namecoin + PowerDNS](#guide-setting-up-dnschain--namecoin--powerdns)

Get yourself a Linux server (they come as cheap as $2/month), and then make sure you have the following software installed:

## Requirements

1. `nodejs` (or `iojs`), and `npm` - We recommend using a package manager to install them
2. [coffee-script](https://github.com/jashkenas/coffee-script) (version 1.7.1+) - install via `npm install -g coffee-script`
3. A supported blockchain daemon like `namecoind`

## Getting Started

1. Install DNSChain using: `npm install -g dnschain` (you may need to put `sudo` in front of that).
2. Run `namecoind` in the background. You can use `systemd` and create a `namecoin.service` file for it based off of [dnschain.service](<../scripts/dnschain.service>).
3. If an update is released, update your copy using: `npm update -g dnschain`

##### Verify it runs

Test DNSChain by simply running `dnschain` from the command line (developers [see here](#Developers.md#Working)). Have a look at the configuration section below, and when you're ready, run it in the background as a daemon. As a convenience, DNSChain [comes with a `systemd` unit file](<../scripts/dnschain.service>) that you can use to run it.

By default, it will start listening for DNS requests on port `53` if you run it as `root`, and `5333` otherwise. You can test `.bit` resolution with `dig`:

    $ dig @localhost -p 5333 okturtles.bit

**:page_facing_up: [Guide to Setting Up DNSChain + Namecoin + PowerDNS on Debian Wheezy](setting-up-dnschain-namecoin-powerdns-server.md)**

<a name="autogen"></a>
##### Verify the SSL/TLS key and certificate fingerprint

By default, DNSChain will automatically use the `openssl` command to generate a random public/private keypair for you.

By default, it will place the private key in `~/.dnschain/key.pem` and `~/.dnschain/cert.pem`, and it will `chmod 600` the private key (making it unreadable by other user accounts on the machine). You should verify the permissions are correct yourself.

If you want, you can generate the key and certificate yourself using a command similar to this:

    openssl req -new -newkey rsa:4096 -days 730 -nodes -sha256 -x509 \
                -subj "/C=US/ST=Florida/L=Miami/O=Company/CN=www.example.com" \
                -keyout key.pem \
                -out cert.pem

The autogen'd certificate uses the `hostname`of your machine for the `CN` ("Common Name").

__When you run DNSChain, it will output the certificate's fingerprint.__

You should see DNSChain say something like this:

    2015-02-22T06:19:39.935Z - info: [TLSServer] Your certificate fingerprint is: E2:3D:01:5D:3C:27:26:67:12:12:05:FA:11:4A:CB:D6:0D:3E:21:1E:4C:D3:43:C0:FC:79:DB:24:91:31:EE:18

That string of hexadecimals is your server's ["One Pin To Rule Them All"](What-is-it.md#MITMProof) that clients will need to verify (once only) if they want to establish a man-in-the-middle-proof connection to DNSChain over TLS (for example, to query its [RESTful API](What-is-it.md#API)).

##### Using nginx for SSL/TLS instead of DNSChain

DNSChain runs several servers, including its own HTTP and HTTPS servers.

You can, if you want, use nginx as the HTTPS server, and then proxy traffic to DNSChain's HTTP server. Just make sure to configure the various ports correctly (you'll need to tell DNSChain to not listen on port `443`), and see to it that nginx is using the same certificate and key that DNSChain is using.

## Configuration

| **:exclamation: Have a look at [config.coffee](<../src/lib/config.coffee>) to see all configuration options and defaults!** |
|-----------------------------------------------------------------------------------------------------------------------------|

DNSChain uses [`nconf`](https://github.com/flatiron/nconf) for all of its configuration purposes. This means that you can configure it using files, command line arguments, and environment variables.

DNSChain looks for its configuration file in one of the following locations:

- `dnschain.conf` locations (in order of preference):
    - `$HOME/.dnschain/dnschain.conf` (Recommended location)
    - `$HOME/.dnschain.conf`
    - `/etc/dnschain/dnschain.conf`

##### Blockchain configuration

DNSChain will look for the configuration files of supported blockchains. If a blockchain has a configuration file, and DNSChain cannot find it, then it will disable support for that blockchain.

You can manually tell DNSChain the location of a blockchain's config file by specifying its path in DNSChain's config file. To do this, create a section with the name of the blockchain (all lowercase, should match the file name of one of [the supported blockchains](<../src/lib/blockchains/>)), and set the `config` variable, like so:

```ini
[namecoin]
config = /weird/path/to/namecoin.conf  
```

DNSChain uses these files to retrieve the information it needs to speak to that blockchain (for example, the JSON-RPC username and password).

##### Example DNSChain configuration

The format of the configuration file is similar to INI, and is parsed by the NodeJS [`properties` module](https://github.com/gagle/node-properties) (in tandem with `nconf`).

Here's an example of a possible `dnschain.conf`:

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

The values you place here will override the values of the `defaults` variable in [config.coffee](<../src/lib/config.coffee>).

Notice that the first level of that object specifies a section in the configuration file (like `log`, `dns`), and after that deeper levels are accessed by using a `.`, as in: `oldDNS.address = 8.8.8.8`

##### Possible configuation options

We hope to add a super-simple web admin interface to DNSChain (most of this work is completed in the `admin` branch). Until that's ready, look at the `defaults` variable in [config.coffee](<../src/lib/config.coffee>) and read the comments.

There are settings for `http` and `dns` servers, Redis caching to improve performance, and anti-DDoS ratelimiting settings as well (for both `http` and `dns` requests). The [Unblock](What-is-it.md#Censorship) setting is still in development.

## Guide: Setting up DNSChain + Namecoin + PowerDNS

As a guide we have an example server setup using Debian 7 and PowerDNS, along with a Namecoin node. This setup will resolve `.bit` domain names and should serve as an example which can be used with other blockchains.

**:page_facing_up: [Guide to Setting Up DNSChain + Namecoin + PowerDNS on Debian Wheezy](setting-up-dnschain-namecoin-powerdns-server.md)**

**:page_facing_up: [Guide to Setting Up DNSChain + Namecoin + PowerDNS on Ubuntu](setting-up-dnschain-namecoin-powerdns-server_ubuntu.md)**

**:page_facing_up: [Guide to Setting Up DNSChain + Namecoin + PowerDNS on FreeBSD](setting-up-dnschain-namecoin-powerdns-server_freebsd.md)**
