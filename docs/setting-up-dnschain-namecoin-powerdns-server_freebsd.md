# Setting up a DNSChain Server on Ubuntu

This is a *how-to* for setting up a [DNSChain](https://github.com/okTurtles/dnschain") server running on [FreeBSD 10.1](https://www.freebsd.org). It will run <nobr>PowerDNS</nobr> recursor, issuing DNS queries for `.com` and `.net` domains as you would expect, but consulting the local Namecoin blockchain to resolve `.bit` domains. Hopefully, this will also provide guidance for getting dnschain
onto pfsense.

Start with a fresh copy of FreeBSD 10.1. Optionally install nano with `pkg install nano`. If DHCP is not picking up, make sure your __/etc/rc.conf__ has
```
synchronous_dhclient="YES"
ifconfig_hn0="DHCP"
```

## Install Namecoin

The Namecoin daemon takes 4-5 hours or more to download the current blockchain. It should be installed first. In this case we'll use the [net-p2p/namecoin port](http://portsmon.freebsd.org/portoverview.py?category=net-p2p&portname=namecoin) from milios. Note that using 'pkg install' will not completely work, as it does not install the namecoind daemon
(only the Qt client). However, if you do use it, it will save time. So issue `pkg install namecoin` (it will install many Qt X11 libs), then uninstall namecoin using
`pkg remove namecoin`. Once you fire off the extract, go get coffee. (Apparently you can not `portsnap update` with extract even if port tree is installed... Note: another option is to use svn `svn up http://svn.freebsd.org/ports/head /usr/ports`):
```
# portsnap fetch
# portsnap extract
# portsnap update
```
Compile the namecoin project. In the install sequence, when you are ask to select DBUS, QRCODES, UPNP, X11, *uncheck X11 (graphics support)*.
```
# cd usr/ports/net-p2p/namecoin
# make install
```
Now is a good time to get a refill, maybe lunch. Once the install is complete, to configure `namecoind`, follow the [Quick start](https://wiki.namecoin.info/index.php?title=Install_and_Configure_Namecoin). 
Rather than creating multiple users, this tutorial will use the current user.
```
# mkdir -p ~/.namecoin \
	&& echo "rpcuser=`whoami`" >> ~/.namecoin/namecoin.conf \
	&& echo "rpcpassword=`openssl rand -hex 30/`" >> ~/.namecoin/namecoin.conf \
	&& echo "rpcport=8336" >> ~/.namecoin/namecoin.conf \
	&& echo "daemon=1" >> ~/.namecoin/namecoin.conf
```

For FreeBSD, instead of `systemd`, we use the rc.d folder for startup - write this file into __/usr/local/etc/rc.d/namecoind__. Make sure to `chmod 555 namecoind`:
```
#!/bin/sh
#
# $$
#

# PROVIDE:	namecoind
# REQUIRE:	SERVERS cleanvar
# BEFORE:	DAEMON
# KEYWORD:	shutdown

#
# Add the following lines to /etc/rc.conf to enable namecoind:
# 
# namecoind_enable="YES"
#

. /etc/rc.subr

name=namecoind
rcvar=namecoind_enable

command=/usr/local/bin/namecoind

# set defaults

namecoind_enable=${namecoind_enable:-"YES"}

export HOME=/root
load_rc_config ${name}
run_rc_command "$1"
```
Add `namecoind_enable="YES" to __/etc/rc.conf__. Issue `service namecoind start` to confirm the script works.
	
As mentioned, `namecoind` is going to begin downloading the blockchain. We won't be able to lookup domain names from the blockchain until it has
made some progress, later when you revisit the Namecoin, you can try:
```
$ namecoind getinfo
$ namecoind name_show d/okturtles
```
as well as checking the RPC interface (use the *rpcuser* and *rpcpassword* from namecoin.conf)
```
$ curl --user rpcuser:rpcpassword --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getinfo","params":[]}'  -H 'content-type: text/plain;' http://127.0.0.1:8336
$ curl -v -D - --user rpcuser:rpcpassword --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"name_show","params":["d/okturtles"]}' -H 'content-type: text/plain;' http://127.0.0.1:8336
```
## Install PowerDNS

Install [PowerDNS](https://www.powerdns.com/) into the system using
```
$ pkg install powerdns-recursor
```
Add `pdns_recursor_enable="YES"` to rc.conf. To start `service pdns-recursor start`. The command to interface with the PowerDNS server is `rec_control`, as in
```
$ rec_control ping		# check if server is alive
```
Next, tell PowerDNS to send requests for `.bit`, `.eth` and `.p2p` domain names to port 5333. This configuration is specified in __/usr/local/etc/pdns/recursor.conf__
```
forward-zones=bit.=127.0.0.1:5333,dns.=127.0.0.1:5333,eth.=127.0.0.1:5333,p2p.=127.0.0.1:5333
export-etc-hosts=off
allow-from=0.0.0.0/0
local-address=0.0.0.0
local-port=53
```
Notice in particular our *forward-zones* declaration. Make sure you restart PowerDNS at this point using `service pdns-recursor restart`.  Then,
confirm that PowerDNS can correctly resolve conventional domain names before we move on. Install `dig` using
`pkg install bind-tools`, then
```
dig @127.0.0.1 okturtles.com
```
You should get a result similar to this, with an IP address found for okturtles.com.

![](http://i.imgur.com/EhVaMUb.png)

   
## Install DNSChain
In FreeBSD, `gcc` and `g++` are not readily available, once added using `pkg install` we need to add links from `gcc` to `gcc48` and `g++` to `g++48` so that `npm` can do the right thing.
```
# pkg install git python
# pkg install gcc
# cd /usr/local/bin
# ln -s gcc48 gcc
# ln -s g++48 gcc
# pkg install npm
# npm install -g coffee-script
# npm install -g dnschain
```
Tell DNSChain to bind to port 5333, but you can use any high port number as long as it matches the port number that PowerDNS is handing off requests to. This was specified earlier in __/usr/local/etc/pdns/recursor.conf__.

Another great feature of DNSChain is that we can expose the lookup results via HTTP. We'll specify port 8000 for this, but you can use any high number port that's open. DNSChain can be setup to be accesed by webserver, via port 8000 for example. For this example, write into __~/.dnschain/dnschain.conf__
 ``` 
[log]
level=info
pretty=true
cli=true

[dns]
port = 5333
oldDNS.address = 8.8.8.8
oldDNS.port = 53

[http]
port=8000
tlsPort=4443
```
Make another rc.d file for dnschain, write this file into __/usr/local/etc/rc.d/dnschain__
```
#!/bin/sh
#
# $$
#

# PROVIDE: dnschain
# REQUIRE: SERVERS cleanvar
# BEFORE:  DAEMON
# KEYWORD: shutdown

#
# Add the following lines to /etc/rc.conf to enable dnschain:
#
# dnschain_enable="YES"
#

. /etc/rc.subr

name=dnschain
rcvar=dnschain_enable
load_rc_config ${name}

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:
export HOME=/root

standalone=/usr/local/bin/dnschain
pidfile=/var/run/dnschain.pid
command=/usr/sbin/daemon
command_args="-cf -p ${pidfile} -u root ${standalone}"

dnschain_enable=${dnschain_enable:-"YES"}

run_rc_command "$1"
```
Make sure to run `chmod 555 /usr/local/etc/rc.d/dnschain`. Run `service dnschain start` to test, then restart the machine. Finally, let's test it by trying to resolve a `.bit` domain name. Note that you may have to wait until a lot of the blockchain is loaded before it works.
```
$ dig @127.0.0.1 okturtles.bit
$ curl http://127.0.0.1:8000/v1/namecoin/key/d%2Fokturtles
```
The first `dig` command ought to return the IP address for `okturtles.bit` and the second should return all the information associated with this domain name, including IP address, TLS fingerprint and more. If so, congratulations, everything works just fine! 

## Bonus

### Checking that processes are running

If you are paranoid like me, you may want to make sure everything auto-starts after a `shutdown -r`, you can use `ps ax | grep ...` to do this, e.g.,
```
root@papaya:~ # ps ax | grep "namecoin\|pdns\|dnschain"
515  -  Ss    0:00.24 /usr/local/sbin/pdns_recursor
518  -  SNs   0:22.92 /usr/local/bin/namecoind
559  -  Is    0:00.00 daemon: /usr/local/bin/dnschain[561] (daemon)
561  -  I     0:03.58 node /usr/local/bin/coffee /usr/local/bin/dnschain
```

### Checking blockchain status

To check the blockchain status, you can use `namecoind getinfo`, e.g., 
```
$ namecoind getinfo
{
    "version" : 38000,
    "balance" : 0.00000000,
    "blocks" : 148076,
    "timeoffset" : -1,
    "connections" : 8,
    "proxy" : "",
    "generate" : false,
    "genproclimit" : -1,
    "difficulty" : 456070389.18823975,
    "hashespersec" : 0,
    "testnet" : false,
    "keypoololdest" : 1428110634,
    "keypoolsize" : 101,
    "paytxfee" : 0.00500000,
    "mininput" : 0.00010000,
    "txprevcache" : false,
    "errors" : ""
}
```
In this example, we are only on block 148076, and according to the [Namecoin block explorer](https://explorer.namecoin.info/), the latest block is 224952. So we wait. Hint: for testing purposes, `namecoind name_show id/greg` shows up early.

### Turning on mining

To turn on mining, you can use `namecoind setgenerate true`.
