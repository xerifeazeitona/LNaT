Routing issues tipically show up when you're setting up a new component on a network or when something has failed (like a NIC).
Otherwise routing issues are normally caused by some manner of configuration error and troubleshooting can be tricky as the normal tools like *traceroute* and *ping* don't give you the information you need.
One tip is to use *curl* when you know the IP resolves to a website as ICMP (ping) is usually blocked.

This section is an extension of the last one and this is the setup
- one host with one NIC at 10.0.1.20
- one host with two NICs at 10.0.1.10 and 10.0.1.11 (this is the one we're connected via SSH)
- both hosts are on the same subnet 10.0.1.0/24
***
Hands On note: since we're defining static ips and messing with networking, I don't know how to automate this *yet*. Don't even bother with remote access to or you'll end up locked out of the machine! Connect via virt-manager console and run this:
- host1
```bash
sudo -i
nmcli con mod System\ eth0 ipv4.method manual ipv4.address 10.0.1.10 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
nmcli con down System\ eth0 
nmcli con up System\ eth0 
nmcli con mod Wired\ connection\ 1 ipv4.method manual ipv4.address 10.0.1.11 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
nmcli con down Wired\ connection\ 1 
nmcli con up Wired\ connection\ 1 
```
- host2
```bash
sudo -i
nmcli con mod System\ eth0 ipv4.method manual ipv4.address 10.0.1.20 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
nmcli con down System\ eth0 
nmcli con up System\ eth0 
nmcli device disconnect eth1
nmcli con del Wired\ connection\ 1 
```
Now we're good to go
***
Since the first NIC of the double NIC host is being used for external connectivity (and tied to the public IP), all tests will be done on the second NIC

```bash
ip route show
default via 10.0.1.1 dev eth0 proto static metric 102 
default via 10.0.1.1 dev eth1 proto static metric 103 
10.0.1.1 dev eth0 proto static scope link metric 102 
10.0.1.1 dev eth1 proto static scope link metric 103 
10.0.1.10 dev eth0 proto kernel scope link src 10.0.1.10 metric 102 
10.0.1.11 dev eth1 proto kernel scope link src 10.0.1.11 metric 103 
```

To send all the traffic to the other host through the second NIC
```bash
ip route add 10.0.1.20 dev eth1
ip route show
default via 10.0.1.1 dev eth0 proto static metric 102 
default via 10.0.1.1 dev eth1 proto static metric 103 
10.0.1.1 dev eth0 proto static scope link metric 102 
10.0.1.1 dev eth1 proto static scope link metric 103 
10.0.1.10 dev eth0 proto kernel scope link src 10.0.1.10 metric 102 
10.0.1.11 dev eth1 proto kernel scope link src 10.0.1.11 metric 103 
10.0.1.20 dev eth1 scope link 

ping 10.0.1.20
PING 10.0.1.20 (10.0.1.20) 56(84) bytes of data.
64 bytes from 10.0.1.20: icmp_seq=2 ttl=64 time=0.463 ms
64 bytes from 10.0.1.20: icmp_seq=3 ttl=64 time=0.463 ms
--- 10.0.1.20 ping statistics ---
3 packets transmitted, 2 received, 33% packet loss, time 2001ms
rtt min/avg/max/mdev = 0.463/0.463/0.463/0.000 ms

ip n
10.0.1.20 dev eth1 lladdr 52:54:00:f2:48:1e REACHABLE
10.0.1.1 dev eth0 lladdr 52:54:00:c7:7f:17 REACHABLE

```
If you check the routing table you should see the rule pointing the traffic to 10.0.0.20 through eth1. With this rule in place, if eth1 goes down for any reason, we wouldn't be able to connect to the other host.

Theoretically, we can bring the interface down
```bash
ip link set eth1 down
ip route show
default via 10.0.1.1 dev eth0 proto static metric 102 
10.0.1.1 dev eth0 proto static scope link metric 102 
10.0.1.10 dev eth0 proto kernel scope link src 10.0.1.10 metric 102 

```
And the rule disappeared and with it our connectivity to the second host. But in this particular setup the connectivity isn't lost because both hosts are on the same subnetwork so the default route serves as a fallback. 
We can confirm this with a ping:
```bash
ping 10.0.1.20
PING 10.0.1.20 (10.0.1.20) 56(84) bytes of data.
64 bytes from 10.0.1.20: icmp_seq=1 ttl=63 time=0.563 ms
From 10.0.1.1 icmp_seq=2 Redirect Host(New nexthop: 10.0.1.20)
From 10.0.1.1: icmp_seq=2 Redirect Host(New nexthop: 10.0.1.20)
64 bytes from 10.0.1.20: icmp_seq=2 ttl=64 time=1.87 ms
64 bytes from 10.0.1.20: icmp_seq=3 ttl=64 time=0.388 ms
64 bytes from 10.0.1.20: icmp_seq=4 ttl=64 time=0.358 ms
--- 10.0.1.20 ping statistics ---
4 packets transmitted, 4 received, +1 errors, 0% packet loss, time 3002ms
rtt min/avg/max/mdev = 0.358/0.794/1.870/0.626 ms
```

To actually see the connectivity disappear we need a more complex setup with each host on a different network and the second NIC acting as a bridge via ip forwarding.

For the next example a few extra rules were added to the routing table:
34.230.144.134 via 10.0.1.20 dev eth0
35.171.81.231 via 10.0.1.20 dev eth0
40.79.78.1 via 10.0.1.20 dev eth0
52.86.216.143 via 10.0.1.20 dev eth0
93.184.216.34 via 10.0.1.20 dev eth0
95.216.24.32 via 10.0.1.20 dev eth0
172.217.7.142 via 10.0.1.20 dev eth0

One tool that you can use to resolve those IPs is the `host` command (bind-utils package)

For example, with the current routing table we can't access example.com via ping or curl so we test with host
```bash
host example.com
example.com has address 93.184.216.34
example.com has IPv6 address 2606:2800:220:1:248:1893:25c8:1946
example.com mail is handled by 0 .
```
Not only we got a result, we also discovered example.com's IP (93.184.216.34). Looking at our routing table, we can see that there's a rule for routing traffic to this particular IP via 10.0.1.20.
Since this is a public acessible website and we know that the device eth0 is able to reach the internet via the default gateway (10.0.1.1), there's no reason for the rule to exist. So we remove it with
```bash
ip route flush 93.184.216.34
```
Now we can ping and curl example.com without problems.
That was just an example of an entry in the routing table that was causing problems, a it was routing to 10.0.10.20 which isn't even configured to be a gateway.

Be careful with the `ip route flush` command, if you don't you might end accidentally deleting the entire routing table and losing all connectivity. Especially bad when you are messing via SSH.

To wrap it up, in terms of troubleshooting your routing table, make sure you're using it in a consistent manner and with good design in mind. Only add routing rules when they are absolutely necessary.
Other thing that you should be aware are policy based routing problems. Unless you have access to the switch or router itself, there isn't much you can do to solve this kind of problem. VPNs can also be tricky but we'll talk more about it in future sections.