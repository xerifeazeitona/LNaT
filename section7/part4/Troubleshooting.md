## Firewall Troubleshooting :: Architecture
The following architecture will be used in this section:
 - Server1 (10.0.1.10) running ssh and http as services, iptables as firewall
 - Client1 (10.0.1.11)
 - Client2 (10.0.1.12)

Before you start troubleshooting firewall problems, it's best to do some sanity checks:
- make sure that the service you're trying to access is active and listening on the right port
- make sure there are no connectivity problems between the hosts

### Checking the host
To check which services are active and in what ports they are listening we can use (on Server1):
```bash
ss -lntp | grep 80
LISTEN     0      128       [::]:80                    [::]:*                   users:(("httpd",pid=2404,fd=4),("httpd",pid=2403,fd=4),("httpd",pid=2402,fd=4),("httpd",pid=2401,fd=4),("httpd",pid=2400,fd=4),("httpd",pid=2399,fd=4))
```
In our example we can see that the web server is active and listening on port 80, so let's double check that with a curl:
```bash
curl -I localhost
HTTP/1.1 200 OK
Date: Fri, 13 Nov 2020 16:55:46 GMT
Server: Apache/2.4.6 (CentOS)
Last-Modified: Fri, 13 Nov 2020 16:37:51 GMT
ETag: "10-5b3ffa6470065"
Accept-Ranges: bytes
Content-Length: 16
Content-Type: text/html; charset=UTF-8
```

### Checking the firewall with iptables
Next (after making sure that all cables are connected), to test the firewall connectivity(on Client1):
```bash
curl -I 10.0.1.10
curl: (7) Failed connect to 10.0.1.10:80; No route to host
```
Clearly there's something preventing Client1 from curling the Server1 headers. Let's jump back to Server1!
Since we know that we're running iptables, let's look at the running config:
```bash
iptables -vnL                                                                                                      
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
  644 61528 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
    0     0 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  lo     *       0.0.0.0/0            0.0.0.0/0           
    4   240 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:22
    0     0 ACCEPT     udp  --  *      *       10.0.1.0/24          0.0.0.0/0            udp dpt:631
    0     0 ACCEPT     tcp  --  *      *       10.0.1.0/24          0.0.0.0/0            tcp dpt:631
    0     0 ACCEPT     udp  --  *      *       10.0.1.0/24          0.0.0.0/0            state NEW udp dpt:123
    0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:25
    0     0 ACCEPT     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW udp dpt:53
    0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:53
    0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:443
    0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:143
    0     0 ACCEPT     tcp  --  *      *       10.0.1.0/24          0.0.0.0/0            state NEW tcp dpt:3128
    0     0 REJECT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited
    0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:80

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 REJECT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT 408 packets, 48624 bytes)
 pkts bytes target     prot opt in     out     source               destination         

```
The important part is that the ACCEPT tcp on port 80 from anywhere to anywhere rule is declared *after* the REJECT all rule. 

Remember that in iptables the order of the rules is very important! In our case the requests are being rejected before the tcp rule can be evaluated.

Quick side note: disabling the firewall to troubleshoot connectivity is never a good idea. Particularly troublesome if you are doing it to a production host, or a host that is connected to the internet.

Back to our problem, the easiest way to solve our issue is to move the 80/tcp rule somewhere above the reject rule. This can be done inline with `iptables` command but it's easier to do via direct edit of the iptables file:
```bash
sudo vim /etc/sysconfig/iptables
```
Find the ACCEPT line, cut the line, paste the line above the REJECT line, save and quit, then **restart iptables**. Now we can go back to Client1 to keep troubleshooting. A simple rerun of the curl command shows that it's working:
```bash
curl -I 10.0.1.10
HTTP/1.1 200 OK
Date: Fri, 13 Nov 2020 17:41:09 GMT
Server: Apache/2.4.6 (CentOS)
Last-Modified: Fri, 13 Nov 2020 16:37:51 GMT
ETag: "10-5b3ffa6470065"
Accept-Ranges: bytes
Content-Length: 16
Content-Type: text/html; charset=UTF-8
```

### Checking the firewall with firewalld
We're back into Server1 but now we're no longer running iptables and are running firewalld instead. Still running apache and ssh though.
Again, we start by checking the running config:
```bash
firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
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
Pretty standard configuration, the only difference from the default one is that the http service was added to the public zone.
If we hop to Client1 and run a `curl 10.0.1.10` we can see that our webserver is working!
Unlike with iptables, this time we're starting with a running configuration and we'll break it to understand the process.

The way we're going to break it is by adding a rich rule to block all traffic from the local subnet:
```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.1.10/24 port port=80 protocol=tcp reject'
success

firewall-cmd --reload
success
```
If we hop back into Client1 and run the same curl, we should get an error:
```bash
curl -I 10.0.1.10
curl: (7) Failed connect to 10.0.1.10:80; Connection refused
```

Back on Server1, let's add a new rich rule, to allow traffic from Client1:
```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.1.11  port port=80 protocol=tcp accept'
success

firewall-cmd --reload
success
```
Now if we hop back into Client1 and run curl again, we still get the same error! What gives?

Let's go back to Server1 and recheck the config
```bash
firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client http ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
        rule family="ipv4" source address="10.0.1.10/24" port port="80" protocol="tcp" reject
        rule family="ipv4" source address="10.0.1.11" port port="80" protocol="tcp" accept
```
We can see that the reject rule is above the accept rule and, since we just saw how order matters with iptables, the first troubleshooting we should do is to reorder the rich rules:
```bash
firewall-cmd --permanent --remove-rich-rule='rule family=ipv4 source address=10.0.1.10/24 port port=80 protocol=tcp reject'
success

firewall-cmd --reload
success
```
At this point Client1 can curl Server1 again, which is expected since the only remaining firewall rule is to accept connections from Client1.
Let's add back the reject rule, since this time we know it will be added *after* the accept rule:
```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.1.10/24 port port=80 protocol=tcp reject'
success

firewall-cmd --reload
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client http ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
        rule family="ipv4" source address="10.0.1.241" port port="80" protocol="tcp" accept
        rule family="ipv4" source address="10.0.1.10/24" port port="80" protocol="tcp" reject
```
Now it looks alright, the accept rule first and then the reject. But alas, Client1 can't curl anymore.
We just found out that order doesn't matter for rich rules and if there's a rich rule rejecting all traffic from a subnet, there's no easy way to single out a specific computer.
One approach to solving this would be to add the accept rule for Client one in a different zone but it's outside the scope of this basic training. Good luck figuring it out by yourself when and if you need it!