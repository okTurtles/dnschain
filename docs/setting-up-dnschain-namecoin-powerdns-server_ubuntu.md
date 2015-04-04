# Setting up a DNSChain Server on Ubuntu

This is a *how-to* for setting up a [DNSChain](https://github.com/okTurtles/dnschain") server running on [Ubuntu 14.04 LTS](https://www.ubuntu.org). It will run <nobr>PowerDNS</nobr> recursor, issuing DNS queries for `.com` and `.net` domains as you would expect, but consulting the local Namecoin blockchain to resolve `.bit` domains.

Start with a fresh copy of Ubuntu 14.04 LTS.

## Install Namecoin

The Namecoin daemon takes 4-5 hours or more to download the current blockchain. It should be installed first.
```
$ sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/p_conrad:/coins/xUbuntu_14.04/ /' >> /etc/apt/sources.list.d/namecoin.list"
$ wget http://download.opensuse.org/repositories/home:p_conrad:coins/xUbuntu_14.04/Release.key
$ sudo apt-key add - < Release.key
$ sudo apt-get update
$ sudo apt-get install namecoin
```
To configure `namecoind`, follow the [Quick start](https://wiki.namecoin.info/index.php?title=Install_and_Configure_Namecoin). Rather than creating multiple users, this
tutorial will use the current user.
```
$ mkdir -p ~/.namecoin \
	&& echo "rpcuser=`whoami`" >> ~/.namecoin/namecoin.conf \
	&& echo "rpcpassword=`openssl rand -hex 30/`" >> ~/.namecoin/namecoin.conf \
	&& echo "rpcport=8336" >> ~/.namecoin/namecoin.conf \
	&& echo "daemon=1" >> ~/.namecoin/namecoin.conf
```
Go ahead and run `namecoind` to get things started. Check progress in downloading the blockchain using `namecoind getinfo`.

For Ubuntu, instead of `systemd`, we use [Upstart](http://upstart.ubuntu.com/cookbook/)-  write this file into `/etc/init/namecoind.conf`, remembering to substitute *yourusername*:
```
description "namecoind"

start on filesystem
stop on runlevel [!2345]
oom never
expect daemon
respawn
respawn limit 10 60 # 10 times in 60 seconds

script
user=<yourusername>
home=/home/$user
cmd=/usr/bin/namecoind
pidfile=$home/.namecoin/namecoind.pid
# Don't change anything below here unless you know what you're doing
[[ -e $pidfile && ! -d "/proc/$(cat $pidfile)" ]] && rm $pidfile
[[ -e $pidfile && "$(cat /proc/$(cat $pidfile)/cmdline)" != $cmd* ]] && rm $pidfile
exec start-stop-daemon --start -c $user --chdir $home --pidfile $pidfile --startas $cmd -b --nicelevel 10 -m
end script
```
Then use `namecoind stop` to stop the process. Issue `sudo initctl reload-configuration` then restart using `sudo shutdown -r now`.
Confirm using `top` that Namecoin starts automatically.
	
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
$ sudo apt-get install pdns-recursor
```
The command to interface with the PowerDNS server is `rec_control`, as in
```
$ sudo rec_control ping		# check if server is alive
```
Next, tell PowerDNS to send requests for `.bit`, `.eth` and `.p2p` domain names to port 5333. This configuration is specified in __/etc/powerdns/recursor.conf__
```
forward-zones=bit.=127.0.0.1:5333,dns.=127.0.0.1:5333,eth.=127.0.0.1:5333,p2p.=127.0.0.1:5333
export-etc-hosts=off
allow-from=0.0.0.0/0
local-address=0.0.0.0
local-port=53
```
Notice in particular our *forward-zones* declaration. Make sure you restart PowerDNS at this point using `sudo service pdns-recursor restart`.  Then,
confirm that PowerDNS can correctly resolve conventional domain names before we move on.
```
dig @127.0.0.1 okturtles.com
```
You should get a result similar to this, with an IP address found for okturtles.com.

![](http://i.imgur.com/iL881lF.png)
   
   
## Install DNSChain

First, update apt-get and install some pre-requisites. Note that while `install npm` installs node.js, `nodejs-legacy` is needed because the binary is now `nodejs` instead of `node` and prerequisites of the dnschain install (hiredis?) will ask for `node`. Do not use `sudo apt-get install node` because this `node` is unrelated to node.js. See this [stackoverflow discussion](http://stackoverflow.com/questions/21168141/can-not-install-packages-using-node-package-manager-in-ubuntu) for details.
```
$ sudo apt-get update
$ sudo apt-get install git npm
$ sudo apt-get install nodejs-legacy		# needed so that node calls nodejs
$ sudo npm install -g coffee-script
$ sudo npm install -g dnschain
```
Tell DNSChain to bind to port 5333, but you can use any high port number as long as it matches the port number that PowerDNS is handing off requests to. This was specified earlier in __/etc/powerdns/recursor.conf__. 

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
Make another Upstart file for dnschain, write this file into __/etc/init/dnschain.conf__
```
description "dnschain"

start on filesystem
stop on runlevel [!2345]
oom never
expect daemon
respawn
respawn limit 10 60 # 10 times in 60 seconds

script
user=<yourusername>
home=/home/$user
cmd=/usr/local/bin/dnschain
pidfile=$home/.dnschain/dnschain.pid
# Don't change anything below here unless you know what you're doing
[[ -e $pidfile && ! -d "/proc/$(cat $pidfile)" ]] && rm $pidfile
[[ -e $pidfile && "$(cat /proc/$(cat $pidfile)/cmdline)" != $cmd* ]] && rm $pidfile
exec start-stop-daemon --start -c $user --chdir $home --pidfile $pidfile --startas $cmd -b --nicelevel 10 -m
end script
```
Run `sudo initctl reload-configuration`, then restart the machine. Finally, let's test it by trying to resolve a `.bit` domain name.
```
$ dig @127.0.0.1 okturtles.bit
$ curl http://127.0.0.1:8000/v1/namecoin/key/d%2Fokturtles
```
The first `dig` command ought to return the IP address for `okturtles.bit` and the second should return all the information associated with this domain name, including IP address, TLS fingerprint and more. If so, congratulations, everything works just fine! 

## Bonus

If you are paranoid like me, you may want to make sure everything auto-starts after a `shutdown -r`, you can use `ps aux | grep ...` to do this, e.g.,
```
tim@kumquat:~$ ps aux | grep "namecoin\|pdns\|dnschain"
tim        980  0.1  9.3 723104 64260 ?        SNl  01:46   0:06 node /usr/local/bin/coffee /usr/local/bin/dnschain
tim        999 31.2 19.8 687524 136052 ?       SNLsl 01:46  20:43 /usr/bin/namecoind
pdns      1308  0.2  0.1 176344  1012 ?        Ssl  01:46   0:11 /usr/sbin/pdns_recursor
tim       1677  0.0  0.3  10600  2304 pts/0    S+   02:53   0:00 grep --color=auto namecoin\|pdns\|dnschain
```
