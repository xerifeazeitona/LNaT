## Firewalls :: Overview
Let's say we have a host running ssh(22) for remote connection, an httpd(80) website and named(53) for bind DNS.
Without a firewall, connections can come and go and there's no problem. Until we enable a firewall...
With the firewall enabled, no connections are coming in or out, unless we set up specific rules to permit that specific traffic.

## Firewalls :: Netfilter
**netfilter** is a framework provided by the Linux kernel
- Packet filtering
- Network address translation
- Port translation

Netfilter is a set of hooks inside the Linux kernel that allows kernel modules to register callback functions with the network stack. A registered callback function is then called back for every packet that traverses the respective hook within the network stack. 

## Firewalls :: Services
If netfilter is the *engine* that runs all things firewall, what are the things that we use for implementation?

- **system-config-firewall** is a (GUI/TUI) frontend that interacts with the **iptables.service** which, in turn, is merely a handler for the **/sbin/iptables** command, which, in turn, interacts with the hooks provided by **netfilter**.
- **D-Bus, firewall-config and firewall-cmd** are frontends that interact with the **firewalld.service** which, in turn, also uses **/sbin/iptables** to interact with the hooks provided by **netfilter**.

## Firewalls :: Practical Example
The exercise is done on a pre configured host (10.0.1.149 CentOS7 running httpd with a simple one liner index.html and firewall disabled). 
First, make sure that httpd is up with:
```bash
ss -lntp | grep :80
LISTEN     0      128       [::]:80                    [::]:*                  
```
Then a simple curl to test the webserver/page:
```bash
curl localhost
<h1>Server 1<h1>
```
We also have a running client vm (10.0.1.11 CentOS base image) which can also curl our server's webpage:
```bash
curl 10.0.1.149
<h1>Server 1<h1>
```
At this point we don't have any firewalls running, let's start iptables
```bash
sudo systemctl start iptables

curl localhost
<h1>Server 1</h1>
```
As expected we can still curl locally, however, if we jump back to the client and try to curl again:
```bash
curl 10.0.1.149
curl: (7) Failed connect to 10.0.1.149:80; No route to host
```
Uh oh... Let's enable tcpdump on the host before we try again:
```bash
tcpdump -i eth0 port 80
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
```
Back to the client, run the curl again, get the same error message, then back into the server we can see that the request has been captured but nothing happened after that: 
```bash
18:58:13.451977 IP client1.ten_network.45026 > server1.ten_network.http: Flags [S], seq 751420183, win 29200, options [mss 1460,sackOK,TS val 1381498 ecr 0,nop,wscale 6], length 0
^C
1 packet captured
1 packet received by filter
0 packets dropped by kernel
```

Let's stop the firewall, run the tcpdump again, hop back into the client and then come back to the server to check the results of tcpdump with the firewall service deactivated.
```bash
^C (to stop tcpdump)
sudo systemctl stop iptables
tcpdump -i eth0 port 80
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes

```
(switch to client1)
```bash
curl 10.0.1.149
<h1>Server 1<h1>
```
(back to server to analyze tcpdump results)
```bash
19:01:06.966888 IP client1.ten_network.45028 > server1.ten_network.http: Flags [S], seq 882504175, win 29200, options [mss 1460,sackOK,TS val 1555013 ecr 0,nop,wscale 6], length 0
19:01:06.967048 IP server1.ten_network.http > client1.ten_network.45028: Flags [S.], seq 3603625899, ack 882504176, win 28960, options [mss 1460,sackOK,TS val 1555159 ecr 1555013,nop,wscale 6], length 0
19:01:06.969001 IP client1.ten_network.45028 > server1.ten_network.http: Flags [.], ack 1, win 457, options [nop,nop,TS val 1555015 ecr 1555159], length 0
19:01:06.969021 IP client1.ten_network.45028 > server1.ten_network.http: Flags [P.], seq 1:75, ack 1, win 457, options [nop,nop,TS val 1555015 ecr 1555159], length 74: HTTP: GET / HTTP/1.1
19:01:06.969117 IP server1.ten_network.http > client1.ten_network.45028: Flags [.], ack 75, win 453, options [nop,nop,TS val 1555161 ecr 1555015], length 0
19:01:06.975085 IP server1.ten_network.http > client1.ten_network.45028: Flags [P.], seq 1:259, ack 75, win 453, options [nop,nop,TS val 1555167 ecr 1555015], length 258: HTTP: HTTP/1.1 200 OK
19:01:06.975913 IP client1.ten_network.45028 > server1.ten_network.http: Flags [.], ack 259, win 473, options [nop,nop,TS val 1555022 ecr 1555167], length 0
19:01:06.975937 IP client1.ten_network.45028 > server1.ten_network.http: Flags [F.], seq 75, ack 259, win 473, options [nop,nop,TS val 1555022 ecr 1555167], length 0
19:01:06.975973 IP server1.ten_network.http > client1.ten_network.45028: Flags [F.], seq 259, ack 76, win 453, options [nop,nop,TS val 1555168 ecr 1555022], length 0
19:01:06.976562 IP client1.ten_network.45028 > server1.ten_network.http: Flags [.], ack 260, win 473, options [nop,nop,TS val 1555023 ecr 1555168], length 0
^C
10 packets captured
10 packets received by filter
0 packets dropped by kernel
```

Without the firewall active we can see the full scope of the request going through. Then the same example was run under the lenses of wireshark.
