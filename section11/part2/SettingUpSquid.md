## Squid Proxy :: Architecture
The architecture is similar to what we've been using:
- Client1 at 10.0.1.11
- Server1 at 10.0.1.10
- Each host has their own firewall and can only communicate over ports 22, 80, 3128 and 8080

## Squid Proxy :: Implementation
Let's start on Server1 and the first thing to do is install and enable squid:
```bash
sudo yum install -y squid
sudo systemctl enable squid
sudo systemctl start squid
```
Next, we need to enable squid on the firewall. Squid is a service recognized by firewalld so it's very easy to do so:
```bash
sudo firewall-cmd --permanent --add-service=squid
sudo firewall-cmd --reload
```
Before we get into configuring Squid, let's take a look at the basic configuration:
```bash
cat /etc/squid/squid.conf | grep "^[^#]"
acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all
http_port 3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
```
As you can see, at the top we have a bunch of ACLs, followed by the denys and allows and at the bottom some refresh patterns.
An important thing to remind is that, like with iptables, the order matters on your squid configuration files.
- At the top we have the private IP ranges
- Then it identifies the SSL and safe ports
- Then after CONNECT we can see that squid 
	- denies everything that isn't considered a safe port
	- denies connections to ports that aren't SSL
	- allows localhost to access the squid manager
	- denies access to manager to everyone else
	- allows localnet and localhost to use squid
	- denies everyone else
- sets squid port to 3128
- sets the coredump directory
- defines some refresh patterns

Now that we got an idea of what default squid does, let's hop on Client1 to set it up to use squid:
```bash
curl -I fsf.org
HTTP/1.0 301 Moved Permanently
Server: nginx/1.1.19
Date: Thu, 19 Nov 2020 20:33:34 GMT
Content-Type: text/html
Content-Length: 185
Location: https://www.fsf.org/
X-Cache: MISS from www.fsf.org
X-Cache-Lookup: MISS from www.fsf.org:3128
Via: 1.0 www.fsf.org (squid/3.1.19)
Connection: keep-alive

export http_proxy="http://10.0.1.10:3128"
curl -I fsf.org
HTTP/1.1 301 Moved Permanently
Server: nginx/1.1.19
Date: Thu, 19 Nov 2020 20:34:24 GMT
Content-Type: text/html
Content-Length: 185
Location: https://www.fsf.org/
X-Cache: MISS from www.fsf.org
X-Cache-Lookup: MISS from www.fsf.org:3128
X-Cache: MISS from server1
X-Cache-Lookup: MISS from server1:3128
Via: 1.0 www.fsf.org (squid/3.1.19), 1.1 server1 (squid/3.5.20)
```
We can see at the bottom on the *Via* line that squid is in use. Now that we've done something with it, we can hop back to Server1 and have a look at the logs:
```bash
tail /var/log/squid/access.log 
1605818064.087     97 10.0.1.11 TCP_MISS/301 404 HEAD http://fsf.org/ - HIER_DIRECT/209.51.188.174 text/html
```
Nice. 

### Blacklisting
Now let's create a blacklist:
```bash
vim /etc/squid/squid.conf
```
Find the INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS line and insert:
```
acl blacklist dstdomain .apache.org .linuxacademy.com
http_access deny blacklist
```
The first line creates the list and its content, and the second line is the rule to deny the contents from the list. 
Save, quit, restart squid and then let's move back to Client1 to test our blacklist:
```bash
curl -I fsf.org
HTTP/1.1 403 Forbidden
Server: squid/3.5.20
Mime-Version: 1.0
Date: Thu, 19 Nov 2020 20:38:14 GMT
Content-Type: text/html;charset=utf-8
Content-Length: 3494
X-Squid-Error: ERR_ACCESS_DENIED 0
Vary: Accept-Language
Content-Language: en
X-Cache: MISS from server1
X-Cache-Lookup: NONE from server1:3128
Via: 1.1 server1 (squid/3.5.20)
Connection: keep-alive
```
Success. Access to the site has been successfully blocked.

### Limiting bandwidth
Now we'll showcase how to limit bandwidth to a particular subnet. It's a bit complicated and there isn't much documentation available but let's just go through it to get a feel on how it's done, so when the need arises at least we know that it can be done and can dive deeper.

Still on Client1, let's install and run the speed test tool:
```bash
sudo yum install python wget
wget -O speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
chmod +x speedtest-cli

./speedtest-cli 
Retrieving speedtest.net configuration...
Testing from REDACTED...
Retrieving speedtest.net server list...
Selecting best server based on ping...
Hosted by REDACTED [4.86 km]: 20.427 ms
Testing download speed................................................................................
Download: 135.94 Mbit/s
Testing upload speed................................................................................................
Upload: 14.72 Mbit/s
```

Back on Server1, open the configuration file again and bellow the blacklist rules we created, add this:
```
acl kiosk_128k src 10.0.1.10/24
delay_pools 1
delay_class 1 3
delay_access 1 allow kiosk_128k
delay_access 1 deny all
delay_parameters 1 64000/64000 -1/-1 16000/64000
```
Save, quit and restart squid. Now if you run the speed test on Client1 again, you should see that the bandwidth has been severely limited.
```bash
./speedtest-cli 
Retrieving speedtest.net configuration...
Testing from REDACTED...
Retrieving speedtest.net server list...
Selecting best server based on ping...
Hosted by REDACTED [4.86 km]: 20.427 ms
Testing download speed................................................................................
Download: 0.17 Mbit/s
Testing upload speed................................................................................................
Upload: 10.07 Mbit/s
```

This was only a brief demonstration of what squid can do, we didn't even touch on caching for example. If you feel like it, do a deep dive when time permits.