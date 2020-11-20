## Firewalld :: Zones
One of the things that sets firewalld apart from iptables is the concept of *zones*.
Each NIC has a **default zone**. Firewalld comes packed with 9 zones, where the **public** zone is the **default** zone.
- **drop**: lowest level of trust, all incoming connections are dropped without a reply
- **block**: similar to drop but instead of dropped, all incomming connections are rejected
- **public**: public untrusted network, with some services accepted by default
- **external**: external networks, in cases where you use the firewall as your gateway. Keeps your internal network private but reachable
- **dmz**: only for computers inside the dmz, being isolated with no access to the rest of the network. Only certain incoming connections are permitted
- **work**: for work enviroments where most of the machines are trusted
- **home**: for home use where even more machines are trusted
- **internal**: internal is the opposite of external networks, used for the internal portion of the gateway the computers are trusted and more services are available by default
- **trusted**: the most open of all zones, all machines on the network are trusted, all connections are accepted

All those zones are listed as xml files and you can find them on `/usr/lib/firewalld/zones/`, for example:
```bash
cat /usr/lib/firewalld/zones/public.xml 
```
```
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Public</short>
  <description>For use in public areas. You do not trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
  <service name="ssh"/>
  <service name="dhcpv6-client"/>
</zone>
```
- **short**: is a short name for the zone
- **description**: is the description of the zone
- **service**: is the service allowed to run in this zone

For example, in the *public* zone we have the services *ssh* and *dhcpv6-client* permitted.

## Firewalld :: Services
Services are a list of port and destinations and can include firewall helper modules automatically loaded for the service. Just like zones, they exist as xml files under `/usr/lib/firewalld/services/`, for example:
```bash
cat /usr/lib/firewalld/services/http.xml 
```
```
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>WWW (HTTP)</short>
  <description>HTTP is the protocol used to serve Web pages. If you plan to make your Web server publicly available, enable this option. This option is not required for viewing pages locally or developing Web pages.</description>
  <port protocol="tcp" port="80"/>
</service>
```
- **short**: is the service's short name
- **description**: is the service description
- **port**: specifies which protocol and port number are used by the service

For example, if a zone calls this service and permits this service in the zone, then tcp port 80 will be opened in the zone.

## Firewalld :: IPSet
IPSets are groups of IP or MAC addresses organized into a list (set). They live on `/etc/firewalld/ipsets/` and they can be whitelists, blacklists, have limited connectivity to or from.
Using IPSets as a source for a zone, you can do some pretty cool things, such as having a programatically main list to get dropped when trying to connect to a host.

## Firewalld :: Practical Examples
The vm is a basic CentOS7 with bash-completion and firewalld installed and started.

To check the current status of the firewall:
```bash
firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
We can see that 
- the active zone is *public*
- target is *default*
- no icmp-block-inversion
- interface is eth0
- no discrete sources
- available services are dhcpv6-client and ssh
- no discrete ports
- no discrete protocols
- no masquerade
- no ports forwarded
- no source ports
- no icmp-blocks
- no rich rules

### Zones
To check which zone is active:
```bash
firewall-cmd --get-active-zones 
public
  interfaces: eth0
```
To check what's the default zone:
```bash
firewall-cmd --get-default-zone 
public
```
To list all available zones:
```bash
firewall-cmd --get-zones
block dmz drop external home internal public trusted work

```
### Ports
To check the **ports** allowed on the active zone:
```bash
firewall-cmd --list-ports
```
To add a port to the active zone:
```bash
firewall-cmd --add-port=100/tcp
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 100/tcp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
We can see that the port 100/tcp was added to the public zone.
### Services
To check the **services** allowed on the active zone:
```bash
firewall-cmd --list-services
dhcpv6-client ssh
```
To add a service to the active zone:
```bash
firewall-cmd --add-service=squid
success

firewall-cmd --list-services
dhcpv6-client squid ssh

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client squid ssh
  ports: 100/tcp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
To check which services are available to be added to a zone:
```bash
firewall-cmd --get-services
RH-Satellite-6 RH-Satellite-6-capsule amanda-client amanda-k5-client amqp amqps apcupsd audit bacula bacula-client bgp bitcoin bitcoin-rpc bitcoin-testnet bitcoin-testnet-rpc ceph ceph-mon cfengine condor-collector ctdb dhcp dhcpv6 dhcpv6-client distcc dns docker-registry docker-swarm dropbox-lansync elasticsearch etcd-client etcd-server finger freeipa-ldap freeipa-ldaps freeipa-replication freeipa-trust ftp ganglia-client ganglia-master git gre high-availability http https imap imaps ipp ipp-client ipsec irc ircs iscsi-target isns jenkins kadmin kerberos kibana klogin kpasswd kprop kshell ldap ldaps libvirt libvirt-tls lightning-network llmnr managesieve matrix mdns minidlna mongodb mosh mountd mqtt mqtt-tls ms-wbt mssql murmur mysql nfs nfs3 nmea-0183 nrpe ntp nut openvpn ovirt-imageio ovirt-storageconsole ovirt-vmconsole plex pmcd pmproxy pmwebapi pmwebapis pop3 pop3s postgresql privoxy proxy-dhcp ptp pulseaudio puppetmaster quassel radius redis rpc-bind rsh rsyncd rtsp salt-master samba samba-client samba-dc sane sip sips slp smtp smtp-submission smtps snmp snmptrap spideroak-lansync squid ssh steam-streaming svdrp svn syncthing syncthing-gui synergy syslog syslog-tls telnet tftp tftp-client tinc tor-socks transmission-client upnp-client vdsm vnc-server wbem-http wbem-https wsman wsmans xdmcp xmpp-bosh xmpp-client xmpp-local xmpp-server zabbix-agent zabbix-server
```
The service list lives on `/usr/lib/firewalld/services/`:
```bash
ll /usr/lib/firewalld/services/
total 616
-rw-r--r--. 1 root root  412 Sep 30 16:12 amanda-client.xml
-rw-r--r--. 1 root root  447 Sep 30 16:12 amanda-k5-client.xml
-rw-r--r--. 1 root root  283 Sep 30 16:12 amqps.xml
[...]
-rw-r--r--. 1 root root  545 Sep 30 16:12 xmpp-server.xml
-rw-r--r--. 1 root root  314 Sep 30 16:12 zabbix-agent.xml
-rw-r--r--. 1 root root  315 Sep 30 16:12 zabbix-server.xml
```
So far we've only been modifying the active zone in a non-permanent way. Once the system is rebooted or we ran a `firewall-cmd --reload`, all the changes made here would be discarded:
```bash
firewall-cmd --reload
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
To make a change to the firewall rules persistent, we need to use the `--permanent` flag while issuing the command.

To create a new service:
```bash
firewall-cmd --permanent --new-service=example
success

firewall-cmd --reload
success

cat /etc/firewalld/services/example.xml
```
```
<?xml version="1.0" encoding="utf-8"?>
<service>
</service>
```
To add/modify the description of a service:
```bash
firewall-cmd --permanent --service=example --set-description="Example Service"
success

firewall-cmd --reload
success

cat /etc/firewalld/services/example.xml
```
```
<?xml version="1.0" encoding="utf-8"?>
<service>
  <description>Example Service</description>
</service>
```
To add a port to a service:
```bash
firewall-cmd --permanent --service=example --add-port=1400-1420/tcp
success

firewall-cmd --reload
success

cat /etc/firewalld/services/example.xml
```
```
<?xml version="1.0" encoding="utf-8"?>
<service>
  <description>Example Service</description>
  <port protocol="tcp" port="1400-1420"/>
</service>
```
### IPSets
To list all available IPSets:
```bash
firewall-cmd --get-ipsets
```
To add an IPSet:
```bash
firewall-cmd --permanent --new-ipset=kiosk --type=hash:ip
success

firewall-cmd --reload
success

cat /etc/firewalld/ipsets/kiosk.xml
```
```
<?xml version="1.0" encoding="utf-8"?>
<ipset type="hash:ip">
</ipset>
```
To add an IP to an IPSet:
```bash
firewall-cmd --permanent --ipset=kiosk --add-entry=10.0.1.11
success

firewall-cmd --reload
success

firewall-cmd --permanent --ipset=kiosk --get-entries
10.0.1.11
```
To add a list of IPs to an IPSet in a single command:
```bash
cat > kiosk_ips.txt << EOL
10.0.1.12
10.0.1.15
192.168.1.0/24
EOL

firewall-cmd --permanent --ipset=kiosk --add-entries-from-file=kiosk_ips.txt
success

firewall-cmd --reload
success

firewall-cmd --permanent --ipset=kiosk --get-entries
10.0.1.11
10.0.1.12
10.0.1.15
192.168.1.0/24
```

Now let's tie it all up, creating a new zone and consuming all that was created in the previous examples:
```bash
firewall-cmd --permanent --new-zone=kiosk
success

firewall-cmd --reload
success

firewall-cmd --permanent --zone=kiosk --add-service=example
success

firewall-cmd --permanent --zone=kiosk --add-source=ipset:kiosk
success

firewall-cmd --reload
success
```
We've created a new zone(kiosk), added the service that we created (example) to the zone so that the only ports opened on the kiosk zone are the ones in the example service, then we added an IPSet (kiosk) which means that the only connectivity the IPs on the list will have, are the ones available in the kiosk zone.

### Rich Rules
Rich rules are a pretty big topic, there's a lot to the rich language and there's some excellent documentation if you look at the man pages:
```bash
man 5 firewalld.richlanguage
```
Inside the docs there are examples that can be very useful in an exam environment, since you can simply copy and paste the examples to get the syntax right.

Rich rules allows us to get really granular with source and destination formatting. To add a rich rule:
```bash
firewall-cmd --add-rich-rule='rule family=ipv4 source address=10.0.1.0/24 destination address=10.0.1.10/24 port port=8080-8090 protocol=tcp accept'
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
	rule family="ipv4" source address="10.0.1.0/24" destination address="10.0.1.10/24" port port="8080-8090" protocol="tcp" accept
```
BTW, if you mess up firewall-cmd will throw an error.

To remove a rich rule:
```bash
sudo firewall-cmd --remove-rich-rule='rule family=ipv4 source address=10.0.1.0/24 destination address=10.0.1.10/24 port port=8080-8090 protocol=tcp accept'
success

firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: dhcpv6-client ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```
That's the basics but, as mentioned before, rich rules are a huge topic. Feel free to do a deep dive on it if you ever feel the need.

There's also this link here https://www.computernetworkingnotes.com/rhce-study-guide/firewalld-rich-rules-explained-with-examples.html

### Using Firewalld to add iptables rules
This is just an example to showcase the power of firewalld but you should avoid this kind of approach unless necessary because things done this way can get pretty messy, pretty quick. Again, avoid this approach if possible:
```bash
firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -o eth1 -j MASQUERADE
success

firewall-cmd --reload
success

firewall-cmd --direct --get-all-rules
ipv4 nat POSTROUTING 0 -o eth1 -j MASQUERADE
```
This can be used in certain edge cases but is convoluted and messy. If you can, always choose a route (iptables or firewalld) and stick to it.