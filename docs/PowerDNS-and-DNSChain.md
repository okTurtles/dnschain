# DNSChain and PowerDNS

**:page_facing_up: See also: [Mike's Guide to Installing Namecoin, DNSChain, and PowerDNS on Debian Wheezy](http://mikeward.net/how-to-setup-a-blockchain-dns-server-with-dnschain/)**

We recommend combining DNSChain with **PowerDNS 3.6.x or higher. 
Installing this on a Debian 7 (wheezy) server, for example, requires getting a more recent version than in the *stable* repo. 

	echo 'deb http://http.debian.net/debian wheezy-backports main' >> /etc/apt/sources.list
	apt-get update
	apt-get -t wheezy-backports install pdns-recursor
	# check if server is alive
	rec_control ping   

Test to ensure that PowerDNS is properly handling DNS queries:
`$ dig @127.0.0.1 okturtles.org`

PowerDNS is going to receive all DNS Queries, and conventional domain names will be resolved as usual. However, we want all queries for blockchain-based TLDs to be passed along to DNSChain to be resolved using a local blockchain.

PowerDNS should listen on port 53 and forward `.bit` and `.dns` (and all blockchain TLD queries) to DNSChain.

You'll need to have something like the following in /etc/powerdns/recursor.conf

	allow-from=0.0.0.0/0
	dont-query=
	export-etc-hosts=off
	forward-zones=bit.=127.0.0.1:5333,dns.=127.0.0.1:5333,eth.=127.0.0.1:5333,p2p.=127.0.0.1:5333
	local-address=0.0.0.0
	local-port=53

DNSChain configuration is covered in more detail [here](How-do-I-run-my-own.md#Configuration). Notice that in the above setup example, we configured PowerDNS to handoff `.bit` and similar queries to a process running on port 5333. We must tell DNSChain to bind to that port. That is done in /etc/dnschain/dnschain.conf:

	[dns]
	host=127.0.0.1
	port=5333
	oldDNS.address = 127.0.0.1
	oldDNS.port = 53

That's it! Test the setup to ensure that PowerDNS is actually passing these requests through to DNSChain:

`$ dig @127.0.0.1 okturtles.bit`

If everything is working correctly, you should see the IP address (192.184.93.146) for okturtles.bit returned, as follows:

	; <<>> DiG 9.8.4-rpz2+rl005.12-P1 <<>> @127.0.0.1 okturtles.bit
	; (1 server found)
	;; global options: +cmd
	;; Got answer:
	;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 47421
	;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
	
	;; QUESTION SECTION:
	;okturtles.bit.			IN	A
	
	;; ANSWER SECTION:
	okturtles.bit.		583	IN	A	192.184.93.146
	
	;; Query time: 2 msec
	;; SERVER: 127.0.0.1#53(127.0.0.1)
	;; WHEN: Tue Nov 25 19:31:11 2014
	;; MSG SIZE  rcvd: 47
