# How-to setup a DNSChain Server

Here's a quick *how-to* for setting up a <a href="https://github.com/okTurtles/dnschain">DNSChain</a> server running on [Debian 7](https://www.debian.org) (Wheezy). This will run <nobr>PowerDNS</nobr> recursor software, which will simply pass queries for next generation domain names to our DNSChain server. 

These blockchain-based domain names are resolved by simply querying the local blockchain; bypassing the conventional DNS altogether. This approach will allow you to resolve these new-fangled domain names as well, thanks to DNSChain. This same approach can be applied using any nameserver software, but to we'll be using PowerDNS in our example just to demonstrate the idea.

So our recursor software will issue DNS queries for `.com` and `.net` domains as you would expect, but will consult the local Namecoin blockchain in order to resolve `.bit` domains. So results for, say, `okturtles.bit` will be returned without engaging other servers on the Internet.

We start with a fresh install of Debian 7 (Wheezy), and take the basic security steps before getting started. Do what you're comfortable with, but it's pretty standard practice to disable root login and so on. One configuration detail worth noting - we are using [systemd](https://wiki.debian.org/systemd) from [weezy-backports](https://packages.debian.org/wheezy-backports/admin/systemd) in our example, since this will be standard in future releases of Debian linux. 

## Getting Started

First, add these sources to __/etc/apt/sources.list__ 

	deb http://security.debian.org/ wheezy/updates main
	deb http://http.debian.net/debian wheezy-backports main

then install systemd:
	
	$ apt-get -t wheezy-backports install systemd systemd-sysv
	

## Namecoin install

In our example, we'll use Namecoin, DNSChain and PowerDNS. It's probably a good idea to first install the Namecoin daemon, since it requires some time to download the blockchain. You can find the latest packages for various linux distros at the [Namecoin site](http://namecoin.info/?p=download).

	# identify source for Namecoin packages
	$ echo 'deb http://download.opensuse.org/repositories/home:/p_conrad:/coins/Debian_7.0/ /' > /etc/apt/sources.list.d/namecoin.list
	$ apt-get update
	$ apt-get install namecoin

We will run Namecoind using a user of the same name, and we'll need a config file to run our Namecoin node:

	$ adduser namecoin
	$ su namecoin
	$ vim ~/.namecoin/namecoin.conf

Our config file will specify a valid RPC username and password, as well as optionally specifying a port to bind to (default is 8336). There are other options, see the [Namecoin wiki](https://wiki.namecoin.info/index.php?title=Install_and_Configure_Namecoin) for more details. Here's a simple example of the __/home/namecoin/.namecoin/namecoin.conf__ file:

	rpcuser=dnsuser
	rpcpassword=dnsuser
	rpcport=8336
	server=1

To run this as a service using systemd, use a unit file similar to [our example file](../scripts/namecoin.service). We saved the file as __/etc/systemd/system/namecoin.service__ 

Start the new service and check to see if it starts without errors. 
 
	$ systemctl enable namecoin.service
	$ systemctl start namecoin

If things go wrong, try checking to see if the paths match what's on your filesystem, and adjust as needed!

As mentioned, `namecoind` is going to begin downloading the blockchain soon after startup. We won't be able to lookup domain names from the blockchain until it has made some progress, so let's revisit testing our namecoin install later.

Meanwhile, we can setup PowerDNS and DNSChain, and then come back and test this, as follows:

	$ namecoind getinfo
	$ namecoind name_show d/okturtles

OK, so basic operations work directly from the command line, now let's check it via the RPC interface.

	$ curl --user dnsuser:dnsuser --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getinfo","params":[]}'  -H 'content-type: text/plain;' http://127.0.0.1:8336
	$ curl -v -D - --user dnsuser:dnsuser --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"name_show","params":["d/okturtles"]}' -H 'content-type: text/plain;' http://127.0.0.1:8336
   
## PowerDNS install

We need [PowerDNS](https://www.powerdns.com/) version 3.6.x or higher. This is currently newer than the version in _stable_ we'll use _wheezy-backports_. Append the following onto __/etc/apt/sources.list__:
 
	deb http://http.debian.net/debian wheezy-backports main

Download and install from the repo, and check to see that it installed, and that it runs.

	apt-get update
	apt-get -t wheezy-backports install pdns-recursor
	rec_control ping   # check if server is alive

Next, we need to tell PowerDNS to send requests for `.bit` domain names to port 5333, where we will soon tell DNSChain to listen. This configuration is specified in __/etc/powerdns/recursor.conf__

	forward-zones=bit.=127.0.0.1:5333,dns.=127.0.0.1:5333,eth.=127.0.0.1:5333,p2p.=127.0.0.1:5333
	export-etc-hosts=off
	allow-from=0.0.0.0/0
	local-address=0.0.0.0
	local-port=53

Notice in particular our *forward-zones* declaration. Even though in our example, we're simply setting up our server to resolve Namecoin's `.bit` domain names, support for `.eth` and `.p2p` domains is on the current roadmap. 

Since we have not yet setup DNSChain, let's just make sure our PowerDNS recursor can correctly resolve conventional domain names before we move on.

	dig @127.0.0.1 okturtles.com

You should get a result similar to this, with an IP address found for okturtles.com.

![](http://i.imgur.com/iL881lF.png)
   

## DNSChain install

DNSChain is written using NodeJS and we need to install this and a few other javascript tools:
  
	apt-get install libc6-dev zlib1g-dev libssl-dev nodejs-dev  
	update-alternatives --install /usr/bin/node nodejs /usr/bin/nodejs 100
	node -v
	curl https://www.npmjs.org/install.sh | sudo sh
	npm -v
	npm install -g coffee-script
	npm install -g grunt-cli

Now we're ready to install DNSChain, and once again, we'll create a user to run DNSChain:

	npm install -g dnschain
	adduser dnschain

We will tell DNSChain to bind to port 5333, but you can use any high port number as long as it matches the port number that PowerDNS is handing off requests to. This was specified earlier in __/etc/powerdns/recursor.conf__. 

Another great feature of DNSChain is that we can expose the lookup results via HTTP. We'll specify port 8000 for this, but you can use any high number port that's open. DNSChain can be setup to be accesed by webserver, via port 8000 for example. Here's an example DNSChain configuration file __/home/dnschain/.dnschain.conf__
  
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


This process will be run by our *dnschain* user, so it needs to be readable.

	chown dnschain.dnschain /home/dnschain/.dnschain.conf

As with the others, we're going to run this as a `systemd` service. Here's [our example unit file](../scripts/dnschain.service), feel free to adjust as needed. 

Note that this unit file also sets up port forwarding so our DNSChain install can run unprivileged using port 5333, while still receiving traffic from port 53. Here is a [more detailed discussion](https://stackoverflow.com/questions/413807/is-there-a-way-for-non-root-processes-to-bind-to-privileged-ports-1024-on-l/21653102#21653102) about this problem of running user processes that listen on ports < 1024.

Let's start DNSChain to ensure that we have it configured correctly.

	$ systemctl enable dnschain
	$ systemctl start dnschain

Finally, let's test it by trying to resolve a `.bit` domain name.

	$ dig @127.0.0.1 okturtles.bit
	$ curl http://127.0.0.1:8000/d/okturtles

The first `dig` command ought to return the IP address for `okturtles.bit` and the second should return all the information associated with this domain name, including IP address, TLS fingerprint and more. If so, congratulations, everything works just fine! 
