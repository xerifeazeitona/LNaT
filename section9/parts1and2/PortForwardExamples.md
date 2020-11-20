We'll be using the same architecture from the previous section here.

## iptables
We'll start with iptables so we've installed it and masked firewalld on Server1. Apache has been modified to listen on port 8080 instead of port 80. 
```bash
sytemctl stop frewalld
systemctl mask firewalld
systemctl start iptables
vim /etc/httpd/conf/httpd.conf
```
Change `Listen 80` to `Listen 8080`, save and quit.

We can check this setup with
```bash
ss -lntp | grep 8080
LISTEN     0      128       [::]:8080                  [::]:*                   users:(("httpd",pid=6023,fd=4),("httpd",pid=6022,fd=4),("httpd",pid=6021,fd=4),("httpd",pid=6020,fd=4),("httpd",pid=6019,fd=4),("httpd",pid=6018,fd=4))
```
This shows that apache (httpd) is indeed listening on port 8080. 
And since iptables has just been installed, we don't have any rules allowing port 8080 (or 80 for that matter).

We want to get the requests over port 80 and forward them to port 8080. Let's start by checking the default iptables config:
```bash
iptables -nL
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            state RELATED,ESTABLISHED
ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0           
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           
ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            state NEW tcp dpt:22
REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
```
Pretty simple setup, on the INPUT chain we have a series of rules ending with a reject, one reject rule on the FORWARD chain and no rules on the OUTPUT chain.

We can also see that the NAT table is empty:
```bash
iptables -L -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
```

If we want to take the incoming requests to port 80 and forward them to port 8080, we need to add a rule to the PREROUTING chain on the NAT table. Which means that the moment the request reaches the network stack, we want to do something with it:
```bash
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

iptables -L -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
REDIRECT   tcp  --  anywhere             anywhere             tcp dpt:http redir ports 8080

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
```
On the NAT table, append to the PREROUTING chain a rule that when a tcp request comes over port 80, redirect it to port 8080.
We can test the rule now but it's not very useful, since we haven't added a rule opening port 8080 on the filter table. 

Let's take care of that. First we check the lines (because our rule needs to be inserted before the reject rule):
```bash
iptables -L --line-number
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
1    ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
2    ACCEPT     icmp --  anywhere             anywhere            
3    ACCEPT     all  --  anywhere             anywhere            
4    ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
5    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination         
1    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination         

```
Now we know we can add to any line above line 5 to bump the reject rule to line number 6:
```bash
iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
```
On line 4 of the INPUT chain, insert a rule that when receiving a tcp request over port 8080 and the request has a state of NEW (since RELATED and ESTABLISHED are already covered in line 1), jump to accept.
```bash
iptables -L --line-number
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
1    ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
2    ACCEPT     icmp --  anywhere             anywhere            
3    ACCEPT     all  --  anywhere             anywhere            
4    ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:webcache
5    ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
6    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination         
1    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination         

```

Now we should be able to test it from the external host (laptop):
```bash
curl 54.144.41.70
<h1>Server1</h1>
curl 54.144.41.70:8080
<h1>Server1</h1>
```
Nice, it doesn't matter if we reach for port 80 or 8080, our firewall rules allow us to sucessfully get Server1 to serve us the web page.

Now, if you remember the use case for the previous section, what we really want is to have Server1 serving its own website on port 80 and Server2's website on port 8080. 

Back on Server1 and before we start, let's get a clean slate on iptables. Since we're running an ephemeral config all we need to do is restart the service:
```bash
systemctl restart iptables
```

Since we need to forward incoming traffic from Server1 to Server2 and back, we're going to use the NAT table:
```bash
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.1.20:80
```
On the NAT table, append to the PREROUTING chain the rule that when a tcp request comes to Server1's port 8080, change its destination to Server2's port 80.
```bash
iptables -nL -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:10.0.1.20:80

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
```

In order for this rule to work, we also need to be able to replace the source IP address with Server1's own IP address. In short, we need to enable masquerading:
```bash
iptables -t nat -A POSTROUTING -j MASQUERADE
```
On the NAT table, append a rule that when the POSTROUTING is achieved, jump to MASQUERADE.
```bash
iptables -nL -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:10.0.1.20:80

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  0.0.0.0/0            0.0.0.0/0           
```

Now if we look at the filter table:
```bash
iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
ACCEPT     icmp --  anywhere             anywhere            
ACCEPT     all  --  anywhere             anywhere            
ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
```
We can see that on the FORWARD chain the only rule is the REJECT all from anywhere to anywhere. In order to make our forwarding to work we need to add a new rule above this one:
```bash
iptables -I FORWARD -p tcp -d 10.0.1.20 --dport 80 -m state --state NEW -j ACCEPT
```
On the filter table, insert on the FORWARD chain a rule that when receiving a tcp request over port 80 and the state is NEW, jump to ACCEPT.
This takes care of the NEW state, now we also need a rule for ESTABLISHED and RELATED:
```bash
iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
```
On the filter table, insert on the FORWARD chain a rule that when the request state is RELATED or ESTABLISHED, jump to ACCEPT.
```bash
iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
ACCEPT     icmp --  anywhere             anywhere            
ACCEPT     all  --  anywhere             anywhere            
ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
ACCEPT     tcp  --  anywhere             10.0.1.20            tcp dpt:http state NEW
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited
```


Next, let's open up port 80 on the firewall:
```bash
iptables -I INPUT 4 -p tcp -m state --state NEW --dport 80 -j ACCEPT
```

Now, since apache was configured to listen on port 8080, we need to change the config on apache to listen on port 80 again:
```bash
cat /etc/httpd/conf/httpd.conf | grep ^Listen
Listen 8080
```
To setup Apache to listen on 80, change the Listen 8080 line to
```
Listen 80
```
save quit and restart apache to activate the new config.

The last thing we need to do before testing is to make sure that ip forwarding is enabled:
```bash
cat /proc/sys/net/ipv4/ip_forward
0
echo 1 > /proc/sys/net/ipv4/ip_forward
```

Now we should be able to test it from the external host (laptop):
```bash
curl 54.144.41.70
<h1>Server1</h1>
curl 54.144.41.70:8080
<h1>Server2</h1>
```
That's it! A bit convoluted but we got there with iptables. Moving on...

## firewalld
The process is more streamlined with firewalld, no need to echo binaries to obscure files or anything like that at least.

Back on Server1:
```bash
sytemctl stop iptables
systemctl mask iptables
systemctl unmask firewalld
systemctl start firewalld
```

Since we're doing it all over again, change apache to listen on port 8080 again.

Now let's start by checking the default config:
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
Pretty standard, we need port 8080 open so:
```bash
firewall-cmd --add-port=8080/tcp
```
Next, we forward all traffic from port 80 to port 80:
```bash
firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080
```
With this we should be able to test it from the external host (laptop):
```bash
curl 54.144.41.70
<h1>Server1</h1>
curl 54.144.41.70:8080
<h1>Server1</h1>
```

Nice. Server1 is serving on both 80 and 8080. Now let's change the config to make Server1 serve his website on port 80 and Server2's website on port 8080.

First change the apache config to listen on port 80 again. Save and restart.

Next, we need to change the current forwarding rule. We could reload firewalld to start with a clean slate but let's take this opportunity to learn how to remove a rule:
```bash
firewall-cmd --remove-forward-port=port=80:proto=tcp:toport=8080
```
Then we add the rule forwarding to Server2:
```bash
firewall-cmd --add-forward-port=port=8080:proto=tcp:toport=80:toaddr=10.0.1.20
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
  forward-ports: port=8080:proto=tcp:toport=80:toaddr=10.0.1.20
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
Looks good, time to enable masquerading:
```bash
firewall-cmd --add-masquerade

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client http ssh
  ports: 
  protocols: 
  masquerade: yes
  forward-ports: port=8080:proto=tcp:toport=80:toaddr=10.0.1.20
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
Way simpler than with iptables for sure! Now we can test from the external host:
```bash
curl 54.144.41.70
<h1>Server1</h1>
curl 54.144.41.70:8080
<h1>Server2</h1>
```

We only did it with http traffic in this exercise but you could do it with pretty much anything. Just don't be a newfag and go out opening everything to the internet. For example, if you want to expose a database server, make sure to add rules that filter incoming requests and only accept those from trusted source IPs.