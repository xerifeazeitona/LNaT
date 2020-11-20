## Port Forwarding :: Architecture
A fairly standard setup with an externally available web host and an internally available database/application host:
- Server1(web server) is 10.0.1.10 and that internal IP is NATed to a public IP. Server1 is running its own firewall
- Server2(database server) is 10.0.1.20 and isn't NATed so the only way to access Server2 from outside is through Server1. Server2 is also running its own firewall
- Between those 2 servers, connectivity is limited to ports 22, 80, 3306 and 8080
- On top of that both servers are running on an environment that limits incoming connectivity. Could be via a VPC firewall, physical firewall or whatever. The important part is that only ports 22, 80 and 8080 can be accessed when coming from outside the network.

## Port Forwarding :: Prep Work
Before starting, it's always a good idea to try to minimize complexity
- Limit/Eliminate configuration variables
- Verify connectivity prior to changing the config (instead of straight up standing up apache, try to connect to port 80 via netcat first)
- Change one thing at a time and test, this way whenever you break something you'll know that it was the last thing you did
- Don't get frustrated! (especially when dealing with iptables and complex chains)

## Port Forwarding :: Use Case
Assuming a setup similar to the one detailed in the architecture above, we have
- A web server that talks to the outside via port 80 (Server1 @ 10.0.1.10)
- A web server that only talks to the previous server via port 80 (Server2 @ 10.0.1.20)
- We want to have Server2 serving web pages to the outside via Server1's port 8080

The first thing we're going to check is if apache is running on both servers, from Server1:
```bash
curl localhost
<h1>Server1</h1>
curl 10.0.1.20
<h1>Server2</h1>
```
All working as expected so far, the next step is to check if Server1's port 80 is accesible from outside. To do that we need to obtain its public IP and curl it from a host that isn't on the same network. (He's using his personal laptop to connect to an AWS instance, not sure how feasible it is in our own infra):
```bash
curl 54.144.41.70
<h1>Server1</h1>
```
Working fine, don't even bother testing Server2 since we know it shouldn't be accessible from outside. Next, let's check if we have connectivity to Server1's port 8080:
```bash
telnet 54.144.41.70 8080
Trying 54.144.41.70...
telnet: connect to address 54.144.41.70: No route to host
```
We have our first fail! Either port 8080 or telnet can be blocked on the firewall, so let's move back into Server1 and test that:
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
Aha, port 8080 is blocked so let's open it up
```bash
firewall-cmd --add-port=8080/tcp
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client http ssh
  ports: 8080/tcp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
Now before moving on, let's test the connectivity with netcat (remember, it's to minimize complexity):
```bash
yum install -y nmap-ncat
nc -l 8080
Hello from the outside!!
```
Jump back to the external host (laptop) and test the connectivity again
```bash
telnet 54.144.41.70 8080
Trying 54.144.41.70...
Connected to 54.144.41.70.
Escape character is '^]'.
Hello from the outside!!
^]
telnet> quit
Connection closed.

```
This time we managed to connect successfully, nice! This means we are ready to do the port forwarding. Note how doing one thing at a time can save a lot of headache.