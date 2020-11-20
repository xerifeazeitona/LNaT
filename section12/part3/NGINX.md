## Nginx :: Architecture
The architecture is exactly the same as the previous one:
- Client1 on 10.0.1.11 will reach Server1 through port 80
- Server1 on 10.0.1.10 will act as the load balancer, has a firewall and will reach the application nodes through port 80
- Node1 on 10.0.1.20 will act as an application node, has a firewall and has a running instance of apache
- Node2 on 10.0.1.30 will act as an application node, has a firewall and has a running instance of apache

The only difference (and merely because we can skip a chunk of the setup) is that this time both nodes will serve on the default port 80 so all you have to do is install and enable apache and those nodes are gtg


## Nginx :: Practical Examples
Starting on Server1, the first thing is to install nginx:
```bash
sudo yum install -y epel-release
sudo yum install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```
Then a quick `firewall-cmd --list-all` shows that http is already enabled on the firewall so we don't have to mess with it.

Now we can start configuring nginx:
```bash
sudo vim /etc/nginx/nginx.conf
```
Just like with HAProxy, Nginx also comes with a default configuration and since we want nothing to do with the web server portion of nginx, we can blow most contents of the config file. It's safe to delete everything below `events { worker_connections 1024;`, just remember to close the curly bracket!

Then add this code below:
```
http {
  upstream demoapp {
    server 10.0.1.20;
	server 10.0.1.30;
  }
  
  server {
    listen 80;
	
	location / {
	  proxy_pass http://demoapp;
	}
  }
}
```
(again there was a typo on the demo that wasn't as exciting as the last one so don't even... just remember to not use underscores on the upstream name)
Just like with HAProxy, Nginx also needs a backend and a frontend. The difference is that Nginx calls the backend *upstream* and frontend *server*.
Save, quit, restart nginx and then the usual round of tests: 
```bash
systemctl restart nginx

ss -lntp
State      Recv-Q Send-Q                                                  Local Address:Port                                                                 Peer Address:Port              
LISTEN     0      128                                                                 *:111                                                                             *:*                   users:(("rpcbind",pid=519,fd=8))
LISTEN     0      128                                                                 *:80                                                                              *:*                   users:(("nginx",pid=4240,fd=6),("nginx",pid=4239,fd=6))
LISTEN     0      128                                                                 *:22                                                                              *:*                   users:(("sshd",pid=1050,fd=3))
LISTEN     0      100                                                         127.0.0.1:25                                                                              *:*                   users:(("master",pid=978,fd=13))
LISTEN     0      128                                                              [::]:111                                                                          [::]:*                   users:(("rpcbind",pid=519,fd=11))
LISTEN     0      128                                                              [::]:22                                                                           [::]:*                   users:(("sshd",pid=1050,fd=4))
LISTEN     0      100                                                             [::1]:25                                                                           [::]:*                   users:(("master",pid=978,fd=14))

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
As you can see, by default Nginx uses the round robin method of balancing. We can easily change this on the config, of course. And the process is the same as in HAProxy, however instead of *source* nginx calls the sticky method *ip_hash*:
```
http {
  upstream demoapp {
    ip_hash;
    server 10.0.1.20;
	server 10.0.1.30;
  }
  
  server {
    listen 80;
	
	location / {
	  proxy_pass http://demoapp;
	}
  }
}
```
Save, quit, restart and run the same tests to get different results. The only difference here is that Client1 was used for test after testing on Server1 but all results were identical (which means it's working as intended!).
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

All in all, HAProxy and Nginx work and are configured in a very similar way and are both excellent balancers. The best one for you will depend on your use case.
