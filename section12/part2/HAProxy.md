## HAProxy :: Architecture
This time everyone is inside the same subnet and this allows for abstraction of the ingress firewall. Easier for demos but something to be considered in real deployments.
- Client1 on 10.0.1.11 will reach Server1 through port 80
- Server1 on 10.0.1.10 will act as the load balancer, has a firewall and will reach the application nodes through port 8080
- Node1 on 10.0.1.20 will act as an application node, has a firewall and has a running instance of apache
- Node2 on 10.0.1.30 will act as an application node, has a firewall and has a running instance of apache

Note: Even though a Client1 is mentioned and should work as intended, all the tests against the nodes were done from Server1 so Client1 doesn't have a real reason to exist in this demo.

## HAProxy :: Implementation
Let's start on Server1 and install, enable and start HAProxy:
```bash
sudo yum install -y haproxy
sudo systemctl enable haproxy
sudo systemctl start haproxy
```
If it's not there yet, add http to the firewall rules:
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```
Next, make sure that apache is installed and listening on port 8080, instead of the default 80, on both Node1 and Node2:
```bash
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd
sudo vim /etc/httpd/conf/httpd.conf (change to `Listen 8080`, save and quit)
sudo systemctl restart httpd
ss -lntp
sudo firewall-cmd --permanent --add-port=8080/tcp
success

sudo firewall-cmd --reload
success

sudo firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 8080/tcp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 

curl localhost:8080
<h1>Node1</h1>
```
Remember to do this for both nodes. For now, there's nothing else to do with the nodes so let's hop back into Server1.
Now we're going to start configuring HAProxy and we do this by editing haproxy.cfg:
```bash
sudo vim /etc/haproxy/haproxy.cfg
```
This configuration file is very well documented and you can get a good idea of what's going on just by reading it. At the bottom of the file there are several examples that you can safely delete before we start, so remove everything from `main frontend which proxys to the backends` until the end of the file.
Start at the now bottom of the file, rich after `maxconn 3000`:
``` 
frontend demo_app
  bind *:80
  mode http
  default_backend apache_nodes

backend apache_nodes
  mode http
  balance roundrobin
  option forwardfor
  server node1 10.0.1.20:8080 check
  server node2 10.0.1.30:8080 check
```
Save, quit and restart haproxy.
Note: During the live example the trainer forgot to put the ports on the nodes and this led to some troubleshooting since haproxy failed to restart. No biggie but for archival purposes the proccess was:
- restart haproxy (no error on screen)
- curl localhost (error)
- ss -lntp (nothing on port 80)
- systemctl status haproxy (failure)
- edit haproxy.cfg, find and fix the error
- restart haproxy (success)
- curl localhost (success)

Now we're ready to test, first a single curl, then 10 of them. Since we're using round robin the results should alternate between node1 and node2:
```bash
curl localhost
<h1>Node1</h1>

for i in {1..10}; do curl localhost; done
<h1>Node2</h1>
<h1>Node1</h1>
<h1>Node2</h1>
<h1>Node1</h1>
<h1>Node2</h1>
<h1>Node1</h1>
<h1>Node2</h1>
<h1>Node1</h1>
<h1>Node2</h1>
<h1>Node1</h1>
```
Success! Now let's try a different balancing. To do that simple edit haproxy.cfg again and change the balancing to source (`balancing source` on the backend), save, quit, restart haproxy and run the same for loop.
```bash
for i in {1..10}; do curl localhost; done
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
<h1>Node2</h1>
```

Same command, very different results! What *source* does is try to apply some best-effort stickiness to the clients.

To test HA part of haproxy, quickly hop to Node2, stop apache, back to Server1 and run the for loop again.
```bash
for i in {1..10}; do curl localhost; done
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
<h1>Node1</h1>
```

Nice!

