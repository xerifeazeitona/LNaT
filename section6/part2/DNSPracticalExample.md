## Name Servers :: Sample Architecture

We'll be working with 3 vm hosts
- Server1 connected on eth0 with IP 10.0.1.10 and will be the primary DNS server
- Server2 connected on eth0 with IP 10.0.1.11 and will be the secondary DNS server
- Client1 connected on eth0 with IP 10.0.1.12 and will just be used for testing

The three hosts are connected to a switch, then a router with access to the internet and somewhere outside of the subnet is a DNS host (10.0.0.2) assigned via DHCP.

The domain that will be used is example.com. To be able to take full control of the DNS of our domain we need to set up our own name servers. To do so, we need a minimum of 2 name servers (ns1.example.com and ns2.example.com).

Our setup doesn't follow best practices as both name servers are in the same location and ideally you would want to have some degree of separation between them.

For this to work in real life you would also need to have your name servers publically accessible via internet.

## Setting up the first Name Server (10.0.1.10)

Note: There are two applications available to set up a name server, bind and unbound. We'll be using bind in this exercise.
Also take note that this exercise doesn't approach security at all, it's just the bare minimum so do it at your own risk and just for lab purposes. The trainer wouldn't do this in his own home network to provide production DNS services

The first thing is to install the necessary packages:
```bash
sudo yum install -y bind bind-utils NetworkManager bash-completion
source /etc/profile
```
The file we'll be working on is `/etc/named.conf`. The syntax in this file is somewhat unusual and it's not a file you have to mess with in day to day operations.
You can check/learn how to do stuff on the example file located in `/usr/share/doc/bind-9.9.4/sample/etc/named.conf`
Once you got a feel for what we're going to do, let's edit the real file:
```bash
sudo vim /etc/named.conf
``` 
Add the host IP to the `listen on port 53` line:
```
listen on port 53 { 127.0.0.1;10.0.1.10; };
```
Then limit queries for only hosts in the same network in the `allow-query` line, and also enable query transfers to the second server:
```
allow-query { localhost; 10.0.1.0/24; };
allow-transfer { localhost; 10.0.1.11; };
```
Next disable recursion right bellow
```
recursion no;
```
Again, pay attention to the comments, this should only be done for academic purposes, don't become a part of the botnet!

Finally, add the zones to the bottom of the file (after the zone "." block and right before the includes)
```
zone "example.com" IN {
	type master;
	file "forward.example.com";
	allow-update { none; };
};

zone "1.0.10.in-addr-arpa" IN {
	type master;
	file "reverse.example.com";
	allow-update { none; };
};
```
Save and quit and we're done here. There are a couple ways to validate our syntax, one would be to put it to run like a madmen, another, more elegant, way is to use the `named-checkconf` command:
```bash
named-checkconf /etc/named.conf
```
With the conf file ready, we can now add the files we declared (forward and reverse). There are examples for this kind of file as well on `/usr/share/doc/bind-9.9.4/sample/var/named/named.empty`.
If you cat the sample file, you can see some useful info:
```bash
cat /usr/share/doc/bind-9.11.4/sample/var/named/named.empty 
$TTL 3H
@	IN SOA	@ rname.invalid. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	NS	@
	A	127.0.0.1
	AAAA	::1
```
- **TTL** is time to live and indicates how long a DNS server can hold this info on cache before having to query again
- The **@** symbol stands for origin in our case is the zone example.com
- **SOA** stands for [Start of Authority](https://en.wikipedia.org/wiki/SOA_record) and contains administrative information about the zone

Now that we have a general idea of how it works, it's time to create our forward file, inside the `/var/named/` directory:
```bash
sudo vim /var/named/forward.example.com
```
Paste this contents inside
```
$TTL 86400
@	IN	SOA		ns1.example.com. server1.example.com. (
	2018091201	;Serial
	3600		;Refresh
	1800		;Retry
	604800		;Expire
	86400		;Minimum TTL
)
@		IN	NS	ns1.example.com.
@		IN	NS	ns2.example.com.
server1	IN	A	10.0.1.10
ns1		IN	A	10.0.1.10
server2	IN	A	10.0.1.11
ns2		IN	A	10.0.1.11
client1	IN	A	10.0.1.12
```
Save and quit, then onwards to the reverse file:
```bash
sudo vim /var/named/reverse.example.com
```
Paste this contents inside
```
$TTL 86400
@	IN	SOA		ns1.example.com. server1.example.com. (
	2018091201	;Serial
	3600		;Refresh
	1800		;Retry
	604800		;Expire
	86400		;Minimum TTL
)
@		IN	NS	ns1.example.com.
@		IN	NS	ns2.example.com.
server1	IN	A	10.0.1.10
ns1		IN	A	10.0.1.10
server2	IN	A	10.0.1.11
ns2		IN	A	10.0.1.11
client1	IN	A	10.0.1.12
10		IN	PTR	server1.example.com.
10		IN	PTR	ns1.example.com.
11		IN	PTR	server2.example.com.
11		IN	PTR	ns2.example.com.
12		IN	PTR	client1.example.com.
```
This file does the reverse lookup, for example instead of returning the IP 10 for server1, it would return server1 for the IP 10
Save and quit, then validate both files with `named-checkzone`:
```bash
named-checkzone example.com /var/named/forward.example.com
zone example.com/IN: loaded serial 2018091201
OK

named-checkzone example.com /var/named/reverse.example.com
zone example.com/IN: loaded serial 2018091201
OK
```
At this point, we're good to enable named and start it. We know the syntax is okay but if there were any other kind of errors in our files, this is where we would pick it up
```bash
sudo systemctl enable named && sudo systemctl start named
```
Now that the service is up, we can start testing it. If you remember the initial setup, our DNS is outside the subnet so even with named up it would look on the internet for name resolution
```bash
dig example.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.6 <<>> example.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 60883
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;example.com.			IN	A

;; ANSWER SECTION:
example.com.		51349	IN	A	93.184.216.34

;; Query time: 5 msec
;; SERVER: 10.0.1.1#53(10.0.1.1)
;; WHEN: Wed Nov 11 21:11:11 UTC 2020
;; MSG SIZE  rcvd: 56
```
However, we can test it by specifying our DNS to dig as an argument
```bash
dig @localhost example.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.6 <<>> @localhost example.com
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 42842
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;example.com.			IN	A

;; AUTHORITY SECTION:
example.com.		86400	IN	SOA	ns1.example.com. server1.example.com. 2018091201 3600 1800 604800 86400

;; Query time: 0 msec
;; SERVER: ::1#53(::1)
;; WHEN: Wed Nov 11 21:11:57 UTC 2020
;; MSG SIZE  rcvd: 88

```
Looks good! The last thing before we move to the next host is to enable DNS on the firewall
```bash
sudo systemctl status {iptables,firewalld}
Unit iptables.service could not be found.
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2020-11-11 21:14:52 UTC; 5s ago
     Docs: man:firewalld(1)
 Main PID: 11449 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─11449 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

Nov 11 21:14:51 localhost systemd[1]: Starting firewalld - dynamic firewall daemon...
Nov 11 21:14:52 localhost systemd[1]: Started firewalld - dynamic firewall daemon.
Nov 11 21:14:52 localhost firewalld[11449]: WARNING: AllowZoneDrifting is enabled. This is considered an insecure configuration option. It will be removed in a future release....ling it now.
Hint: Some lines were ellipsized, use -l to show in full.

firewall-cmd --permanent --add-service=dns
success

firewall-cmd --reload
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client dns ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 

```

## Setting up the Client (10.0.1.12)
Now we're connected to the Client VM and no modification has been done to the base image yet. bind-utils came already installed here but remember to install it (and bash-completion) before starting.
```bash
sudo yum install -y bind-utils bash-completion
source /etc/profile
```

Let's do a quick `dig` to test if our server is properly configured:
```bash
dig @10.0.1.10 server1.example.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.6 <<>> @10.0.1.10 server1.example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 35848
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;server1.example.com.		IN	A

;; ANSWER SECTION:
server1.example.com.	86400	IN	A	10.0.1.10

;; AUTHORITY SECTION:
example.com.		86400	IN	NS	ns2.example.com.
example.com.		86400	IN	NS	ns1.example.com.

;; ADDITIONAL SECTION:
ns1.example.com.	86400	IN	A	10.0.1.10
ns2.example.com.	86400	IN	A	10.0.1.11

;; Query time: 3 msec
;; SERVER: 10.0.1.10#53(10.0.1.10)
;; WHEN: Wed Nov 11 21:19:19 UTC 2020
;; MSG SIZE  rcvd: 132

```
Looking good, now let's check how the DNS resolver is configured:
```bash
cat /etc/resolv.conf 
; generated by /usr/sbin/dhclient-script
search ten_network
nameserver 10.0.1.1

```
Next, let's make sure we're using NetworkManager to manage the network stack (In the vm used in the exercise the stack was being managed by cloud-init)
```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
nmcli
eth0: connected to System eth0
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:56:B0:E1, hw, mtu 1500
        ip4 default
        inet4 10.0.1.12/24
        route4 0.0.0.0/0
        route4 0.0.0.0/0
        route4 10.0.1.0/24
        route4 10.0.1.0/24
        inet6 fe80::5054:ff:fe56:b0e1/64
        route6 fe80::/64
        route6 ff00::/8

lo: unmanaged
        "lo"
        loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

DNS configuration:
        servers: 10.0.1.1
        domains: ten_network
        interface: eth0
```
Now we're ready to start setting up our custom DNS and the first step is to change from dhcp to static:
```bash
nmcli con mod CON_NAME ipv4.method manual ipv4.addresses 10.0.1.12/24 ipv4.gateway 10.0.1.1
sudo systemctl restart network

nmcli device show 
GENERAL.DEVICE:                         eth0
GENERAL.TYPE:                           ethernet
GENERAL.HWADDR:                         52:54:00:56:B0:E1
GENERAL.MTU:                            1500
GENERAL.STATE:                          100 (connected)
GENERAL.CONNECTION:                     System eth0
GENERAL.CON-PATH:                       /org/freedesktop/NetworkManager/ActiveConnection/2
WIRED-PROPERTIES.CARRIER:               on
IP4.ADDRESS[1]:                         10.0.1.12/24
IP4.GATEWAY:                            10.0.1.1
IP4.ROUTE[1]:                           dst = 10.0.1.0/24, nh = 0.0.0.0, mt = 100
IP4.ROUTE[2]:                           dst = 0.0.0.0/0, nh = 10.0.1.1, mt = 100
IP6.ADDRESS[1]:                         fe80::5054:ff:fe56:b0e1/64
IP6.GATEWAY:                            --
IP6.ROUTE[1]:                           dst = ff00::/8, nh = ::, mt = 256, table=255
IP6.ROUTE[2]:                           dst = fe80::/64, nh = ::, mt = 256

GENERAL.DEVICE:                         lo
GENERAL.TYPE:                           loopback
GENERAL.HWADDR:                         00:00:00:00:00:00
GENERAL.MTU:                            65536
GENERAL.STATE:                          10 (unmanaged)
GENERAL.CONNECTION:                     --
GENERAL.CON-PATH:                       --
IP4.ADDRESS[1]:                         127.0.0.1/8
IP4.GATEWAY:                            --
IP6.ADDRESS[1]:                         ::1/128
IP6.GATEWAY:                            --

```
We should see the proper IP but no DNS yet, since we still have to set it up.
Next, check `/etc/resolv.conf` again to see if it's being managed by NetworkManager and if there are any lines there(besides the Generated by NetworkManager, that is), nuke them.
```bash
cat /etc/resolv.conf 
# Generated by NetworkManager
```
With this we have a clean slate with no DNS. Let's add ours:
```bash
nmcli con mod CON_NAME ipv4.dns 10.0.1.10 ipv4.dns-search example.com
sudo systemctl restart network

ping server1.example.com
PING server1.example.com (10.0.1.10) 56(84) bytes of data.
64 bytes from 10.0.1.10 (10.0.1.10): icmp_seq=1 ttl=64 time=0.365 ms
64 bytes from 10.0.1.10 (10.0.1.10): icmp_seq=2 ttl=64 time=0.422 ms
64 bytes from 10.0.1.10 (10.0.1.10): icmp_seq=3 ttl=64 time=0.392 ms
--- server1.example.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 0.365/0.393/0.422/0.023 ms
```
If we can ping server1 it's doing what we wanted. Onwards to the second name server!

## Setting up the second Name Server (10.0.1.11)
The process to set up this server is the same as we did on the first one, so connect to it and start by installing the necessary packages:
```bash
sudo yum install -y bind bind-utils NetworkManager bash-completion
source /etc/profile
```
Then edit `/etc/named.conf`
```bash
sudo vim /etc/named.conf
``` 
Add the host IP to the `listen on port 53` line:
```
listen on port 53 { 127.0.0.1;10.0.1.11; };
```
Then limit queries for only hosts in the same network in the `allow-query` line, and also enable query transfers to the second server:
```
allow-query { localhost; 10.0.1.0/24; };
```
Next disable recursion right bellow
```
recursion no;
```
Again, pay attention to the comments, this should only be done for academic purposes, don't become a part of the botnet!

Finally, add the zones to the bottom of the file (after the zone "." block and right before the includes). This part is a little different from the first name server as this one is a slave:
```
zone "example.com" IN {
	type slave;
	file "slaves/example.com.fwd";
	masters { 10.0.1.10; };
};

zone "1.0.10.in-addr-arpa" IN {
	type slave;
	masters { 10.0.1.10; };
};
```
Save and quit and we're done here. There are a couple ways to validate our syntax, one would be to put it to run like a madmen, another, more elegant, way is to use the `named-checkconf` command:
```bash
named-checkconf /etc/named.conf
```
And that should be it, in terms of DNS configuration, for this server. We don't need to do the extra work done on the first server because all this one is doing is pulling the zone information from the master and then storing that information under `/var/named/slaves/example.com.fwd`

We still need to open up the firewall though:
```bash
sudo systemctl status {iptables,firewalld}
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload
```
At this point, we're good to enable named and start it. We know the syntax is okay but if there were any other kind of errors in our files, this is where we would pick it up
```bash
sudo systemctl enable named && sudo systemctl start named
```
Now that the service is up, we can start testing it by specifying our DNS to dig as an argument
```bash
dig @localhost server1.example.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.6 <<>> @localhost server1.example.com
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4504
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;server1.example.com.		IN	A

;; ANSWER SECTION:
server1.example.com.	86400	IN	A	10.0.1.10

;; AUTHORITY SECTION:
example.com.		86400	IN	NS	ns1.example.com.
example.com.		86400	IN	NS	ns2.example.com.

;; ADDITIONAL SECTION:
ns1.example.com.	86400	IN	A	10.0.1.10
ns2.example.com.	86400	IN	A	10.0.1.11

;; Query time: 0 msec
;; SERVER: ::1#53(::1)
;; WHEN: Wed Nov 11 21:33:53 UTC 2020
;; MSG SIZE  rcvd: 132

```
Looks good! The last thing before we wrap it up is to hop back into the Client host to test this second name server.

## Testing the second name server on the Client (10.0.1.12)
We can test with a simple `dig`, using Server2 as a resolver:
```bash
dig @10.0.1.11 server1.example.com

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.6 <<>> @10.0.1.11 server1.example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 19546
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;server1.example.com.		IN	A

;; ANSWER SECTION:
server1.example.com.	86400	IN	A	10.0.1.10

;; AUTHORITY SECTION:
example.com.		86400	IN	NS	ns1.example.com.
example.com.		86400	IN	NS	ns2.example.com.

;; ADDITIONAL SECTION:
ns1.example.com.	86400	IN	A	10.0.1.10
ns2.example.com.	86400	IN	A	10.0.1.11

;; Query time: 2 msec
;; SERVER: 10.0.1.11#53(10.0.1.11)
;; WHEN: Wed Nov 11 21:34:54 UTC 2020
;; MSG SIZE  rcvd: 132
```

We can also ping server2:
```bash
ping server2.example.com
PING server2.example.com (10.0.1.11) 56(84) bytes of data.
64 bytes from 10.0.1.11 (10.0.1.11): icmp_seq=1 ttl=64 time=0.798 ms
64 bytes from 10.0.1.11 (10.0.1.11): icmp_seq=2 ttl=64 time=0.515 ms
64 bytes from 10.0.1.11 (10.0.1.11): icmp_seq=3 ttl=64 time=0.731 ms
^C
--- server2.example.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2001ms
rtt min/avg/max/mdev = 0.515/0.681/0.798/0.122 ms
```

And that's it! This section demonstrated how to set up an INSECURE pair of DNS servers and how to setup a client to consume the service provided by the servers.