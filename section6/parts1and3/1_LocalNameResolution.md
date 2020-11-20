This section uses a CentOS7 vm (10.0.1.248) and since we're going to be working with DNS, it's a good idea to have `bind-utils` installed. The tools in the bind-utils package use DNS to resolve things while things like ping, getent and most other tools don't.

We'll be using the domain *latoys.com* as an example so let's start by testing it:
```bash
host latoys.com
latoys.com has address 45.79.199.162
latoys.com mail is handled by 10 mail.latoys.com.

getent ahosts latoys.com
45.79.199.162   STREAM latoys.com
45.79.199.162   DGRAM  
45.79.199.162   RAW    
```
Same info on both commands which is expected since we haven't done any modifications yet. 
We can also obtain more details with curl
```bash
curl -I latoys.com
HTTP/1.1 200 OK
Date: Wed, 11 Nov 2020 19:49:46 GMT
Server: Apache
Last-Modified: Tue, 21 Jul 2020 01:27:02 GMT
Accept-Ranges: bytes
Content-Length: 71
Content-Type: text/html

```
Keep the contents of *Server* in mind, it will change soon.

If we run
```bash
grep host /etc/nsswitch.conf
#hosts:     db files nisplus nis dns
hosts:      files dns myhostname

```
We can see that the order of resolution is files -> dns -> myhostname. *files* is the hosts file (`/etc/hosts`) and since it looks there first, before checking the DNS all we have to do to redirect the domain is to edit the hosts file
```bash
echo "10.0.1.248 latoys.com" >> /etc/hosts
```
Now if we run the same commands again, the results will be different
```bash
host latoys.com
latoys.com has address 45.79.199.162
latoys.com mail is handled by 10 mail.latoys.com.

getent ahosts latoys.com
10.0.1.248      STREAM latoys.com
10.0.1.248      DGRAM  
10.0.1.248      RAW    
```
Running curl again will fail
```bash
url -I latoys.com
curl: (7) Failed connect to latoys.com:80; Connection refused

```
That's because we don't have Apache running on this server. Let's fix it:
```bash
yum install -y httpd
systemctl start httpd

curl -I latoys.com
HTTP/1.1 403 Forbidden
Date: Wed, 11 Nov 2020 19:55:08 GMT
Server: Apache/2.4.6 (CentOS)
Last-Modified: Thu, 16 Oct 2014 13:20:58 GMT
ETag: "1321-5058a1e728280"
Accept-Ranges: bytes
Content-Length: 4897
Content-Type: text/html; charset=UTF-8
```
Now if we compare the results with the first time we ran curl, we can see that the contents of *Server* (and a few others) have changed, confirming that now curl is picking our local site instead of the legitimate one.

This is a quick and dirty way to resolve domains locally.

Just as another demo of how it works, if you edit `/etc/nsswitch.conf` and change from files -> dns to dns -> files, then run host, getent and curl again, you'll see that now everything is picking up the legit site again, which indicates that DNS is taking priority over the hosts file.

After this a quick demo was shown on how to mirror a website with wget example.com into /var/www/html and then adding the proper entry in the hosts file. Interesting but not enough to notetake at this moment.