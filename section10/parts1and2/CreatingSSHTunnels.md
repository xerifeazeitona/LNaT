## SSH Tunnel Examples :: Architecture
The architecture is similar to all the ones that came previously. The only difference from the previous section is that all hosts are inside the same subnetwork:
- Server1 (10.0.1.10) public nat and firewall
- Server2 (10.0.1.20) internal and firewall
- Client1 (10.0.1.11)

Client1 can only talk to Server1 via ports 22, 80 and 8080.
Server2 can only talk to Server1 via ports 22, 80, 3306 and 8080.
Client1 can't talk to Server2 and vice versa.

Since all hosts are on the same network, we're going to create a rich rule on the firewall on Server2 to block Client1. This way we can simulate that separation between Client1 and Server2.

So, on Server2:
```bash
firewall-cmd --add-rich-rule='rule family=ipv4 source address=10.0.1.11 reject'
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources:
  services: dhcpv6-client http mysql ssh
  ports:
  protocols:
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
        rule family="ipv4" source address="10.0.1.11" reject
```
We won't be coming back to Server2 anytime soon, so let's take the opportunity to check if apache is properly set up:
```bash
curl localhost
<h1>Server2</h1>
```

Now we're ready to start tunneling away, let's jump to Client1 and test connectivity:
```bash
curl 10.0.1.10
<h1>Server1</h1>
curl 10.0.1.20
curl: (7) Failed connect to 10.0.1.20:80; Connection refused
```
Let's install tmux to make it easier to follow:
```bash
yum install -y tmux
tmux
```
Hit `^b`, `%` to split the screen in half and now we're really ready to start.

## Local Tunnel
We want to be able to curl ourselves on port 8080 and get the content served on Server2's port 80:
```bash
ssh -L 8080:10.0.1.20:80 user@10.0.1.10
```
Now that we have an SSH tunnel established, switch panes to test it:
```bash
ss -lntp
State      Recv-Q Send-Q                                                  Local Address:Port                                                                 Peer Address:Port              
LISTEN     0      128                                                                 *:111                                                                             *:*                  
LISTEN     0      128                                                         127.0.0.1:8080                                                                            *:*                   users:(("ssh",pid=12761,fd=5))
LISTEN     0      128                                                                 *:22                                                                              *:*                  
LISTEN     0      100                                                         127.0.0.1:25                                                                              *:*                  
LISTEN     0      128                                                              [::]:111                                                                          [::]:*                  
LISTEN     0      128                                                             [::1]:8080                                                                         [::]:*                   users:(("ssh",pid=12761,fd=4))
LISTEN     0      128                                                              [::]:22                                                                           [::]:*                  
LISTEN     0      100                                                             [::1]:25                                                                           [::]:*                  
```
We can see that we're listening on port 8080! So now if we curl port 8080:
```bash
curl localhost:8080
<h1>Server2</h1>

curl 10.0.1.20
curl: (7) Failed connect to 10.0.1.20:80; Connection refused
```
We can see the content from Server2 even though we're firewalled! 

If we wanted we could even have the content from Server1 on a different local port as well. First terminate the current ssh connection, then:
```bash
ssh -L 8080:10.0.1.20:80 -L 80:10.0.1.10:80 user@10.0.1.10
```
Leave the connection opened, move to the other pane and:
```bash
ss -lntp
State      Recv-Q Send-Q                                                  Local Address:Port                                                                 Peer Address:Port              
LISTEN     0      128                                                                 *:111                                                                             *:*                  
LISTEN     0      128                                                         127.0.0.1:80                                                                              *:*                  
LISTEN     0      128                                                         127.0.0.1:8080                                                                            *:*                  
LISTEN     0      128                                                                 *:22                                                                              *:*                  
LISTEN     0      100                                                         127.0.0.1:25                                                                              *:*                  
LISTEN     0      128                                                              [::]:111                                                                          [::]:*                  
LISTEN     0      128                                                             [::1]:80                                                                           [::]:*                  
LISTEN     0      128                                                             [::1]:8080                                                                         [::]:*                  
LISTEN     0      128                                                              [::]:22                                                                           [::]:*                  
LISTEN     0      100                                                             [::1]:25                                                                           [::]:*                  

curl localhost:8080
<h1>Server2</h1>

curl localhost:80
<h1>Server1</h1>
```
Success!! Just a quick reminder don't forget that when you open ssh on the standard port 22 you'll be opening yourself to a world of pain. At the very least have key pair authentication only and also choose a different port for ssh.

## Remote Tunnel
Still on Client1, just terminate the current SSH session and since in our remote use case from the previous section Server2 also can't access Client1, let's add a firewall rule for that:
```bash
sudo firewall-cmd --add-rich-rule='rule family=ipv4 source address=10.0.1.20 reject'
sudo firewall-cmd --list-all
curl localhost
<h1>Client1</h1>
curl 10.0.1.10
<h1>Server1</h1>
```
In order to make Client1 web content available to Server2, using Server1 as an intermediate host:
```bash
ssh -R 8080:localhost:80 user@10.0.1.10
```
Now we're going to test on Server2, instead of accessing it directly, just switch to the other pane and let's do a couple hops:
```bash
ssh user@10.0.1.10
ssh user@10.0.1.20
curl localhost
<h1>Server2</h1>
curl 10.0.1.10
<h1>Server1</h1>
curl 10.0.1.10:8080
curl: (7) Failed connect to 10.0.1.20:80; Connection refused
```
Even though the tunnel is up, we're not able to get Client1 content via Server1... That's because there is a security bit in place and we need to alter Server1's ssh configuration. Since we're already connected to it on our tunnel panel, switch to it and:
```bash
vim /etc/sshd_config
```
Find the line with `GatewayPorts` and make sure it's uncommented and set to *yes*. Save and quit, restart SSH, logout and back in:
```bash
systemctl restart sshd
exit
ssh -R 8080:localhost:80 user@10.0.1.10
```
Now that we can switch panes again and test connectivity from Server2 one more time:
```bash
curl 10.0.1.10:8080
<h1>Client1</h1>
```
This time it worked, despite being firewalled Server2 successfully managed to obtain Client1 content.

## Dynamic Tunnel
To showcase this one we're on an external host (laptop) that has a graphical environment going on.

First open the terminal and:
```bash
ssh -D 8080 user@Server1
```
Leave the connection open, move to a web browser (firefox)
- Hamburger, preferences, search for *proxy*, hit settings
	- Manual proxy configuration
	- SOCKS Host: localhost Port: 8080
	- OK

Now you should be able to navigate and see the web content from all 3 hosts
 - Server1 at 10.0.1.10
 - Client1 at 10.0.1.11
 - Server2 at 10.0.1.20

This was a very quick example of using a socks proxy browser. We'll be talking a lot more about this in the next section.