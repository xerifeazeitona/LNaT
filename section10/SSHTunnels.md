## SSH Tunneling :: Architecture
The architecture is similar to the port forwarding section. Two hosts in a VPC, each host has its own firewall and only a few ports are open:
- Server1(web server) is 10.0.1.10 and that internal IP is NATed to a public IP. Server1 is running its own firewall
- Server2(database server) is 10.0.1.20 and isn't NATed so the only way to access Server2 from outside is through Server1. Server2 is also running its own firewall
- Between those 2 servers, connectivity is limited to ports 22 and 80
- On top of that both servers are running on an environment that limits incoming connectivity. Could be via a VPC firewall, physical firewall or whatever. The important part is that only ports 22 and 80 on Server1 can be accessed when coming from outside the network.

There are 3 types of SSH tunnels that we can create and we'll check each one.

## SSH Tunneling :: Local
This is where you're hitting your local host, over a port, to access some kind of remote content. Let's imagine you have a laptop at home and you want to access Server2 on your office network. 
As we already mentioned, there is no direct connection to Server2 from outside the local network. Server1 however, can be accessed from the outside and can also access Server2.
We already know that you *could* facilitate connectivity to Server2 using [port forwarding](:/6a522c36f8e5448fab6d152fc9a3ac0f) since we did that on the last section, but that would assume that you have root level access to Server1 in order to modify those firewall rules. In our current scenario we don't have that level of access anymore and also, we don't want to make this connection available to everyone. This is just for you.

In our example we'll treat the servers as 2 web servers, 1 public, 1 internal and we want to view the content from the internal one from outside. So, in short:
- Server1 has a public IP that we can access from our laptop
- Server2 isn't accessible but we want to view that content

We're going to create an SSH connection over port 22 to Server1, which in turn has connectivity to Server2's port 80. We're going to build the tunnel, so that we can view the remote content from our own device, over port 8080. 

A command to do this would look somewhat like this:
```bash
ssh -L 8080:Server2:80 user@Server1
```
- We're SSHing locally (`-L`) 
- The port on our local host is `8080`
- `Server2` has the content that we want to see (note that Server2's IP could also be used here)
- The content that we want to access on Server2 is being served over port `80`
- And we're logging into the intermediary host (Server1) with the credentials `user@Server1`

With this command we would be able to curl localhost on port 8080 on our laptop to see the content that Server2 serves over port 80.
It takes some time to get used to this but the idea is that the host that you're SSHing to is the intermediate host.

## SSH Tunneling :: Remote
Keeping the same architecture, Server2 can't access our laptop. Let's assume we have some development code that Server2 wants to consume. Maybe Server2 isn't even a server but just another host on the internal network and wants to access the external host for any reason. 
In any case both ends can access Server1, so on the external host we create an SSH Tunnel to Server1 over port 22, then we make the content on the external host available through Server1's port 8080, which then tunnels the traffic back to the external host over port 80.

The resulting command would look like this:
```bash
ssh -R 8080:localhost:80 user@Server1
```
-R is for remote and the entire command translates to port 8080 on the intermediate host (Server1) will tunnel to port 80 on the localhost (external host). Therefore any connections to Server1 over port 8080 receive the content that the external host is serving over port 80.

## SSH Tunneling :: Dynamic
The dynamic tunnel allows us to use an SSH intermediate host as a proxy. The command is like this:
```bash
ssh -D 8080 user@Server1
```
We create the SSH connection, we designate a port on the target host (Server1) as our socks proxy port. We can then configure a browser to use that address and port as our proxy, then all our web traffic would pipe through there. This can work as a pseudo VPN.

Those are the main ideas behind an SSH tunnel, on the next section we'll dive deeper with some practical examples.