Centos7.5 vm ready to go, create with Terraform, configure with Ansible

to show routing table
```bash
route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.122.1   0.0.0.0         UG    0      0        0 eth0
192.168.122.0   0.0.0.0         255.255.255.0   U     0      0        0 eth0
```
or
```bash
ip route
default via 192.168.122.1 dev eth0 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.65 

```
Instead of using routes to make something reachable, you can also use routes to make something unreachable. For example, you can block traffic to cloudflare with:
```bash
ip route add prohibit 1.1.1.1
```
You can test the block with
```bash
ping 1.1.1.1
curl -I 1.1.1.1
```
You can unblock/remove the block rule with
```bash
ip route flush 1.1.1.1
```
Now you can `ping` and `curl` cloudflare again.

Note that changes made with `ip` are not persistent through reboots. To make a persistent change you would need to edit a network config file that was not shown in the demo. (`/etc/sysconfig/network-scripts/route-eth0` on RHEL/CentOS)

At this point an extra virtual NIC was added to showcase that we can add a static route for a particular NIC:
```bash
ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
default via 192.168.122.1 dev eth1 proto dhcp metric 101 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 
192.168.122.0/24 dev eth1 proto kernel scope link src 192.168.122.115 metric 101 

ip route add 1.1.1.1 via 192.168.122.1 dev eth0

ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
default via 192.168.122.1 dev eth1 proto dhcp metric 101 
1.1.1.1 via 192.168.122.1 dev eth0 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 
192.168.122.0/24 dev eth1 proto kernel scope link src 192.168.122.115 metric 101 

nmcli
eth0: connected to System eth0
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:72:C0:1D, hw, mtu 1500
        ip4 default
        inet4 192.168.122.59/24
        route4 0.0.0.0/0
        route4 192.168.122.0/24
        route4 1.1.1.1/32
        inet6 fe80::5054:ff:fe72:c01d/64
        route6 fe80::/64
        route6 ff00::/8

eth1: connected to Wired connection 1
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:46:4B:1C, hw, mtu 1500
        inet4 192.168.122.115/24
        route4 0.0.0.0/0
        route4 192.168.122.0/24
        inet6 fe80::35eb:823e:7096:eb70/64
        route6 fe80::/64
        route6 ff00::/8

lo: unmanaged
        "lo"
        loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

DNS configuration:
        servers: 192.168.122.1
        interface: eth0

        servers: 192.168.122.1
        interface: eth1

```
With this setup all traffic to cloudflare will be redirected through eth0 via the default gateway. 
Cleanup before moving on
```bash
ip route flush 1.1.1.1
```
## Ruining connectivity is easy!
Here a few examples of how things can be easily broken with bad routing rules

The demo showed the same redirection above but using eth1 instead but it was a flop due to no connectivity on eth1 there was no way to ping or curl anything pointing to it. 
```bash
ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
default via 192.168.122.1 dev eth1 proto dhcp metric 101 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 
192.168.122.0/24 dev eth1 proto kernel scope link src 192.168.122.115 metric 101 

ip route add 1.1.1.1 via 192.168.122.1 dev eth1

ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
default via 192.168.122.1 dev eth1 proto dhcp metric 101 
1.1.1.1 via 192.168.122.1 dev eth1 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 
192.168.122.0/24 dev eth1 proto kernel scope link src 192.168.122.115 metric 101 

nmcli
eth0: connected to System eth0
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:72:C0:1D, hw, mtu 1500
        ip4 default
        inet4 192.168.122.59/24
        route4 0.0.0.0/0
        route4 192.168.122.0/24
        inet6 fe80::5054:ff:fe72:c01d/64
        route6 fe80::/64
        route6 ff00::/8

eth1: connected to Wired connection 1
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:46:4B:1C, hw, mtu 1500
        inet4 192.168.122.115/24
        route4 0.0.0.0/0
        route4 192.168.122.0/24
        route4 1.1.1.1/32
        inet6 fe80::35eb:823e:7096:eb70/64
        route6 fe80::/64
        route6 ff00::/8

lo: unmanaged
        "lo"
        loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

DNS configuration:
        servers: 192.168.122.1
        interface: eth0

        servers: 192.168.122.1
        interface: eth1

nmcli device disconnect eth1
Device 'eth1' successfully disconnected.

nmcli device 
DEVICE  TYPE      STATE         CONNECTION  
eth0    ethernet  connected     System eth0 
eth1    ethernet  disconnected  --          
lo      loopback  unmanaged     --          

ping 1.1.1.1
connect: Network is unreachable

curl -I 1.1.1.1
curl: (7) Failed to connecto to 1.1.1.1: Network is unreachable
```

Then (after another ip route flush and bringing eth1 down) a route was created to a bad gateway
```bash
ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 

ip route add 1.1.1.1 via 192.168.122.20

ip route
default via 192.168.122.1 dev eth0 proto dhcp metric 100 
1.1.1.1 via 192.168.122.20 dev eth0 
192.168.122.0/24 dev eth0 proto kernel scope link src 192.168.122.59 metric 100 

nmcli
eth0: connected to System eth0
        "Red Hat Virtio"
        ethernet (virtio_net), 52:54:00:72:C0:1D, hw, mtu 1500
        ip4 default
        inet4 192.168.122.59/24
        route4 0.0.0.0/0
        route4 192.168.122.0/24
        route4 1.1.1.1/32
        inet6 fe80::5054:ff:fe72:c01d/64
        route6 fe80::/64
        route6 ff00::/8

eth1: disconnected
        "Red Hat Virtio"
        1 connection available
        ethernet (virtio_net), 52:54:00:46:4B:1C, hw, mtu 1500

lo: unmanaged
        "lo"
        loopback (unknown), 00:00:00:00:00:00, sw, mtu 65536

DNS configuration:
        servers: 192.168.122.1
        interface: eth0

ping -c4 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
From 192.168.122.59 icmp_seq=1 Destination Host Unreachable
From 192.168.122.59 icmp_seq=2 Destination Host Unreachable
From 192.168.122.59 icmp_seq=3 Destination Host Unreachable
From 192.168.122.59 icmp_seq=4 Destination Host Unreachable

--- 1.1.1.1 ping statistics ---
4 packets transmitted, 0 received, +4 errors, 100% packet loss, time 2999ms

curl -I 1.1.1.1
curl: (7) Failed connect to 1.1.1.1:80; No route to host
```

The idea behind breaking things like this is to make possible to better understand how to resolve things via static routing when things are actually broken.
For example, if have no connectivity and only see the default route when you run a `ip route`, you probably need to add another gateway. Maybe talk to someone that has more experience over this particular network, or if you are the administrator pay attention and make sure that the routing table is correct.

If you're working with multiple networks, maybe the router is in a different network and you would need to setup IP Forwarding.