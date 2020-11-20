Connection Testing is one of the most important troubleshooting skills you can have. When integrated systems break, or really anything breaks or doesn't function as desired, being able to find and resolve connectivity issues quickly, is an essential tool.

## Connection Testing :: Order and Tools

### OSI Layers
**Layer 2**: Data Link (MAC) - switch and VLAN configuration, MAC addressing and IP conflicts. tool: **arping**
**Layer 3**: Network (IP) - addressing and routing, bandwidth, network authentication. tools: **ping, traceroute, tracepath**
**Layer 4**: Transport - blocked ports, firewalls. tools: **ss, telnet, tcpdump, nc**
**Layer 5-7**: Application or service function. tools: **dig, service tools**

How you go about testing is really up to you, but it's common practice to start with the application layer and work down the layers. The premisse being that the network isn't as likely to change as the application environment is. However, if you work at an organization that makes constant changes to the network topology, you can start on layer 1 making sure that all cables are plugged.
Lastly in an all-hands outage situation it would make sense to divide and conquer with each team evaluating a specific layer to speed up the whole process.

## Connection Testing :: Architecture
### Server1 
- CentOS7 vm 
- 2 virtual NICs
	- eth0: 10.0.1.10
	- eth1: 10.0.1.20
- ssh on port 22
- httpd on eth1 port 80
- Firewall (firewalld)

By default apache will listen on all available interfaces
```bash
cat /etc/httpd/conf/httpd.conf | grep ^Listen
Listen 80
```
To setup Apache to listen only on eth1, change the `Listen 80` line to
```
Listen 10.0.1.20:80
```
Also make sure httpd is stopped, for exercise purposes

### Client1
- CentOS7 vm
- 1 NIC on eth0 (10.0.1.11)

We start on Client1, running a simple curl
```bash
curl -I 10.0.1.20
curl: (7) Failed connect to 10.0.1.20:80; No route to host
```
No good... let's hop into Server1 to start troubleshooting.
```bash
nmcli
eth0: connected to System eth0
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:DE:E6:39, hw, mtu 1500
        ip4 default
        inet4 10.0.1.10/32
        route4 10.0.1.10/32
        route4 10.0.1.1/32
        route4 0.0.0.0/0
        inet6 fe80::5054:ff:fede:e639/64
        route6 fe80::/64
        route6 ff00::/8

eth1: connected to Wired connection 1
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:5E:66:D9, hw, mtu 1500
        inet4 10.0.1.20/32
        route4 10.0.1.20/32
        route4 10.0.1.1/32
        route4 0.0.0.0/0
        inet6 fe80::e67f:ab56:b0db:cf99/64
        route6 fe80::/64
        route6 ff00::/8

lo: unmanaged
        "lo"
        loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

DNS configuration:
        servers: 10.0.1.1
        interface: eth0

        servers: 10.0.1.1
        interface: eth1

```
Here we can see that everything is working as intended, both NICs are up and have their respective IPs, the DNS is ok for both interfaces as well.

Next, to check which services are active and in what ports they are listening we can use (on Server1):
```bash
ss -lntp
State      Recv-Q Send-Q                                                  Local Address:Port                                                                 Peer Address:Port              
LISTEN     0      128                                                                 *:111                                                                             *:*                   users:(("rpcbind",pid=525,fd=8))
LISTEN     0      128                                                                 *:22                                                                              *:*                   users:(("sshd",pid=1054,fd=3))
LISTEN     0      100                                                         127.0.0.1:25                                                                              *:*                   users:(("master",pid=979,fd=13))
LISTEN     0      128                                                              [::]:111                                                                          [::]:*                   users:(("rpcbind",pid=525,fd=11))
LISTEN     0      128                                                              [::]:22                                                                           [::]:*                   users:(("sshd",pid=1054,fd=4))
LISTEN     0      100                                                             [::1]:25                                                                           [::]:*                   users:(("master",pid=979,fd=14))
```
Uh oh, looks like apache isn't running (no service listening on port 80)! Let's fix that:
```bash
systemctl start httpd

ss -lntp
State      Recv-Q Send-Q                                                  Local Address:Port                                                                 Peer Address:Port              
LISTEN     0      128                                                                 *:111                                                                             *:*                   users:(("rpcbind",pid=525,fd=8))
LISTEN     0      128                                                         10.0.1.20:80                                                                              *:*                   users:(("httpd",pid=13324,fd=3),("httpd",pid=13323,fd=3),("httpd",pid=13322,fd=3),("httpd",pid=13321,fd=3),("httpd",pid=13320,fd=3),("httpd",pid=13319,fd=3))
LISTEN     0      128                                                                 *:22                                                                              *:*                   users:(("sshd",pid=1054,fd=3))
LISTEN     0      100                                                         127.0.0.1:25                                                                              *:*                   users:(("master",pid=979,fd=13))
LISTEN     0      128                                                              [::]:111                                                                          [::]:*                   users:(("rpcbind",pid=525,fd=11))
LISTEN     0      128                                                              [::]:22                                                                           [::]:*                   users:(("sshd",pid=1054,fd=4))
LISTEN     0      100                                                             [::1]:25                                                                           [::]:*                   users:(("master",pid=979,fd=14))

```
Now we can see that httpd is listening on 10.0.1.20:80! But alas, if we move to Client1 and curl again, nothing happens. Back to Server1 and now that we know that the interfaces are up and apache is running, it's time to check the firewall.
To find out what firewall service is being used:
```bash
systemctl status iptables
Unit iptables.service could not be found.

systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2020-11-13 18:40:55 UTC; 1h 40min ago
     Docs: man:firewalld(1)
 Main PID: 2341 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─2341 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

Nov 13 18:40:55 localhost systemd[1]: Starting firewalld - dynamic firewall daemon...
Nov 13 18:40:55 localhost systemd[1]: Started firewalld - dynamic firewall daemon.
Nov 13 18:40:55 localhost firewalld[2341]: WARNING: AllowZoneDrifting is enabled. This is considered an insecure configuration option. It will be removed in a future release. ...ling it now.
Hint: Some lines were ellipsized, use -l to show in full.
```
Now that we know it's running firewalld, let's check the status:
```bash
firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
Looks like httpd wasn't added to the services, fix that with
```bash
firewall-cmd --permanent --add-service=http
success

firewall-cmd --reload
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources: 
  services: dhcpv6-client http ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
Now we see http on the service list. Back to Client1 to test and realize that it's not working... back to Server1.

***
**Hands on note**: this was enough to make Client1 curl Server1 successfully in the labs, but we'll do everything for completion even if we don't know how to force the assymetrical routing issue with AWS.
***

So far we've verified that the services are running and the firewall is set up properly, let's try a local curl:
```bash
curl -I 10.0.1.20
HTTP/1.1 200 OK
Date: Fri, 13 Nov 2020 20:27:05 GMT
Server: Apache/2.4.6 (CentOS)
Last-Modified: Fri, 13 Nov 2020 18:40:52 GMT
ETag: "10-5b4015e379394"
Accept-Ranges: bytes
Content-Length: 16
Content-Type: text/html; charset=UTF-8
```
It works on this machine so we can rule out layers 5-7 from the troubleshooting. Since we ruled out the firewall it's not layer 4. So now we need to start looking at routing information.
```bash
route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.1.1        0.0.0.0         UG    102    0        0 eth0
0.0.0.0         10.0.1.1        0.0.0.0         UG    103    0        0 eth1
10.0.1.1        0.0.0.0         255.255.255.255 UH    102    0        0 eth0
10.0.1.1        0.0.0.0         255.255.255.255 UH    103    0        0 eth1
10.0.1.10       0.0.0.0         255.255.255.255 UH    102    0        0 eth0
10.0.1.20       0.0.0.0         255.255.255.255 UH    103    0        0 eth1
```
In this case we can see a few entries that doesn't make a lot of sense that are probably left over from the cloud-init script that created this instance on AWS and since we have this knowledge we can assume that we're running into some assymetrical routing issue.
Requests will come in and out through eth0 at the default gateway and the interface we need to interact with is eth1. So let's try to add some policy based routing and see if we can get things sorted out:
```bash
ip route add 10.0.1.0/24 dev eth0 tab 1

ip route add 10.0.1.0/24 dev eth1 tab 2

ip route show tab 1
10.0.1.0/24 dev eth0 scope link 

ip route show tab 2
10.0.1.0/24 dev eth1 scope link 
```
We've created two routing tables, now let's add a rule to use them
```bash
ip rule add from 10.0.1.0/24 tab 1
ip rule add from 10.0.1.0/24 tab 2
```
Now we should be able to reach Client1 from eth1
```bash
ping -I eth1 10.0.1.11
PING 10.0.1.11 (10.0.1.11) 56(84) bytes of data.
64 bytes from 10.0.1.11: icmp_seq=1 ttl=64 time=0.609 ms
From 10.0.1.1 icmp_seq=2 Redirect Host(New nexthop: 10.0.1.11)
From 10.0.1.1: icmp_seq=2 Redirect Host(New nexthop: 10.0.1.11)
64 bytes from 10.0.1.11: icmp_seq=2 ttl=64 time=0.961 ms
From 10.0.1.1 icmp_seq=3 Redirect Host(New nexthop: 10.0.1.11)

--- 10.0.1.166 ping statistics ---
3 packets transmitted, 2 received, +2 errors, 33% packet loss, time 2001ms
rtt min/avg/max/mdev = 0.609/0.785/0.961/0.176 ms
```
Success! Now if we hop back into Client1 all tests should pass:
```bash
ping -c4 10.0.1.20
PING 10.0.1.20 (10.0.1.20) 56(84) bytes of data.
64 bytes from 10.0.1.20: icmp_seq=1 ttl=64 time=3.44 ms
64 bytes from 10.0.1.20: icmp_seq=2 ttl=64 time=0.404 ms
64 bytes from 10.0.1.20: icmp_seq=3 ttl=64 time=0.486 ms
64 bytes from 10.0.1.20: icmp_seq=4 ttl=64 time=0.456 ms

--- 10.0.1.20 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3001ms
rtt min/avg/max/mdev = 0.404/1.198/3.448/1.299 ms

curl -I 10.0.1.20
HTTP/1.1 200 OK
Date: Fri, 13 Nov 2020 20:35:29 GMT
Server: Apache/2.4.6 (CentOS)
Last-Modified: Fri, 13 Nov 2020 18:40:52 GMT
ETag: "10-5b4015e379394"
Accept-Ranges: bytes
Content-Length: 16
Content-Type: text/html; charset=UTF-8
```
All problems solved. In this case it was a layer 3 issue. That's not very common but it's important to see that it happens. We didn't have to go down to layer 2 since we're running VMs but if layer 3 was ok and we still didn't have connectivity from Client1 to Server1 the next step would be a:
```bash
arping -c4 10.0.1.20
ARPING 10.0.1.20 from 10.0.1.166 eth0
Unicast reply from 10.0.1.20 [52:54:00:5E:66:D9]  1.150ms
Unicast reply from 10.0.1.20 [52:54:00:5E:66:D9]  1.177ms
Unicast reply from 10.0.1.20 [52:54:00:5E:66:D9]  1.162ms
Unicast reply from 10.0.1.20 [52:54:00:5E:66:D9]  1.619ms
Sent 4 probes (1 broadcast(s))
Received 4 response(s)
```
from Client1.

## Troubleshooting tools

### telnet
One of the most useful troubleshooting tool on any system is **telnet**, because it will let you test against any port.

To start using, it must be installed on both hosts:
```bash
yum install -y telnet
```
Once it's installed on the server and the client, you can use it like this (from the client):
```bash
telnet 10.0.1.20 80
Trying 10.0.1.20...
Connected to 10.0.1.20.
Escape character is '^]'.
^]
telnet> quit
Connection closed.
```
If it connects, it's the same as getting a successful curl but it works on any port. For example we know that we only added port 80 to Server1's firewall, so we can't connect to 443 but we can test it, just to be sure and see what telnet shows when the port is closed:
```bash
telnet 10.0.1.20 443
Trying 10.0.1.20...
telnet: connect to address 10.0.1.20: No route to host
```

### netcat
Let's say you are building a host and you want to test connections before standing up the actual services. That's where **netcat** comes in. It's an extremely useful and versatile tool that you definitely should get comfortable with.
Install (on Server1) with:
```bash
yum install -y nmap-ncat
```
To test it, let's open a random port on the firewall:
```bash
firewall-cmd --add-port=100/tcp
success
```
Then start netcat on that port:
```bash
ncat -l 100
```
Now that Server1 is listening, hop into Client1 and telnet to that port:
```bash
telnet 10.0.1.10 100
Trying 10.0.1.10...
Connected to 10.0.1.10.
Escape character is '^]'.
this is a test message
^]
telnet> quit
Connection closed.
```
Just type in some random garbage and when you're done, quit telnet and jump back to Server1 and you'll see that what you typed on Client1 has appeared here! Extremely useful to test ports indeed.

### tcpdump
In our scenario, tcpdump works in a similar way that netcat. It can be used to test connectivity to a specific port when there's no service running there yet.
To use tcpdump, we must first install it on Server1:
```bash
yum install -y tcpdump
```
Start monitoring on our already opened port:
```bash
tcpdump port 100
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes

```
Now if you hop back into Client1 and run the same telnet command, you will get a connection error. That's because unlike netcat, tcpdump is only observing the port activity but is not actually listening to it. However when you hop back to Server1 you will see that a connection was attempted.
You can also use tcpdump to monitor all activity from a specific host instead of a port:
```bash
tcpdump -i eth1 src host 10.0.1.11
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
21:04:43.629118 IP client1.ten_network.56656 > server1.http: Flags [S], seq 465080943, win 29200, options [mss 1460,sackOK,TS val 8834749 ecr 0,nop,wscale 6], length 0
21:04:43.631743 IP client1.ten_network.56656 > server1.http: Flags [.], ack 1668354168, win 457, options [nop,nop,TS val 8834751 ecr 8831833], length 0
21:04:43.631769 IP client1.ten_network.56656 > server1.http: Flags [P.], seq 0:74, ack 1, win 457, options [nop,nop,TS val 8834751 ecr 8831833], length 74: HTTP: HEAD / HTTP/1.1
21:04:43.641137 IP client1.ten_network.56656 > server1.http: Flags [.], ack 242, win 473, options [nop,nop,TS val 8834761 ecr 8831845], length 0
21:04:43.641240 IP client1.ten_network.56656 > server1.http: Flags [F.], seq 74, ack 242, win 473, options [nop,nop,TS val 8834761 ecr 8831845], length 0
21:04:43.641640 IP client1.ten_network.56656 > server1.http: Flags [.], ack 243, win 473, options [nop,nop,TS val 8834762 ecr 8831846], length 0
21:04:48.643713 ARP, Reply client1.ten_network is-at 52:54:00:5e:d0:86 (oui Unknown), length 28
```
Hop back into Client1 and
```bash
curl 10.0.1.20
```
Back in Server1 you will see that tcpdump has logged all the traffic from Client1 curling the web server(pasted above). 
You can export tcpdump activity to a pcap file, which can be imported into wireshark for further analysis. Something we'll touch on soon.