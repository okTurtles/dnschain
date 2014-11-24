PowerDNS and DNSChain

https://forums.okturtles.com/index.php?topic=8.0

We recommend combining DNSChain with PowerDNS 3.6+. Have PowerDNS listen on port 53 and forward `.bit` and `.dns` (and any other DNSChain-related queries) to DNSChain.

You'll need to have something like the following in /etc/powerdns/recursor.conf

	allow-from=0.0.0.0/0   
	dont-query=   
	export-etc-hosts=off   
	forward-zones=bit.=127.0.0.1:6333,dns.=127.0.0.1:5333
	local-address=0.0.0.0   
	local-port=53

Of course in /etc/dnschain/dnschain.conf you'll need to tell DNSChain to listen on the appropriate ports:

	[dns]
	host=127.0.0.1
	port=5333
	oldDNS.address = 127.0.0.1
	oldDNS.port = 53

