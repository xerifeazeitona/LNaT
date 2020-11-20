## IPTables :: Tables
IPTables does indeed use some tables that contain the policies for how to handle different network scenarios. These tables can be seen as categories for the rules:
- **Filter Table**: Used for determining if a packet is permitted to continue or be denied
- **NAT Table**: Used for performing network address translation rules by determining how to modify a packet's source or destination address to effect routing
- **Mangle Table**: Used for altering the IP headers of a packet in order to modify TTL, hops etc.
- **Raw Table**: Used for opting out of connection tracking
- **Security Table**: Used for setting SELinux security context values on packets or connections

## IPTables :: Netfilter
We know that netfilter is the engine powering the firewall and that IPTables is the mechanism whereby we implement the firewall. We also know that netfilter provides a set of hooks for actions on network activities, so let's examine how netfilter and iptables interface:

| Netfilter (hook) | IPTables (chain) | Description |
| --- | --- | --- |
| NF_IP_PRE_ROUTING | PREROUTING | triggered by incoming traffic after entering the network stack and processed before routing decisions |
| NF_IP_LOCAL_IN | INPUT | triggered after the incoming packet is routed if internal |
| NF_IP_FORWARD | FORWARD | triggered after the incoming packet is routed if remote (forwarded) |
| NF_IP_LOCAL_OUT | OUTPUT | triggered by local outbound traffic once it enters the network stack |
| NF_IP_POST_ROUTING | POSTROUTING | triggered by any outbound traffic, after routing, prior to traversing medium |

## IPTables :: Rules

**Matching**: Determines what disposition a packet must have in order to be matched against a target.
**Jump Targets (action)**: Normally divided into terminating and non-terminating (the chain of evaluation). Jump targets are a non-terminating and move the evaluation to a different chain. The most common actions are ACCEPT, REJECT and DROP

Examples:
```bash
iptables -t filter -A INPUT -p tcp --dport 22 -j ACCEPT
```
Use the iptables command to 
- add a rule to the *filter* table (`-t filter`)
- appending the rule to the INPUT chain (`-A INPUT`)
- when using TCP protocol (`-p tcp`)
- on destination port 22 (`--dport 22`)
- the action (jump target) is jumped to ACCEPT (`-j ACCEPT`)

```bash
iptables -I INPUT 5 -s 10.0.1.0/24 -j REJECT
```
Use the `iptables` command to
- insert a rule on the INPUT chain at line 5 (`-I INPUT 5`)
- when the source is from the subnet 10.0.1.0/24 (`-s 10.0.1.0/24`)
- the action (jump target) is jumped to REJECT (`-j REJECT`)

In short, the first example tells iptables to accept all tcp connections from any host via port 22 when using the filter table and the second example tells iptables to reject all connections from a specific subnetwork when using any table.

## IPTables :: States
States are connection dispositions that can be used in matching. Those states can be:
- **NEW**: A new packet not associated with any existing connection
- **ESTABLISHED**: Established traffic (SYN/ACK)
- **RELATED**: Packets associated with a connection already in the system, but not an existing connection
- **INVALID**: Unrouteable or unindentifiable packets not associated with an existing connection or suitable for a new connection
- **UNTRACKED**: Packets set in the raw table chain to bypass connection tracking
- **SNAT**: Source modified by NAT
- **DNAT**: Destination modified by NAT

If you imagine for a moment, that you have a brand new host and you create a rule to block all incoming and outcoming traffic, except for port 22 (so that you can control it remotely). You would find that your host couldn't effectively connect to anything else (to run updates for example). 
This is the reason why you generally have a line (at the beginning of every default iptables implementation) permiting RELATED and ESTABLISHED connections. That way if your hosts initiates the connection, it becomes ESTABLISHED (or RELATED in a few cases) and you're able to have that 2-way connection.

## IPTables :: Practical examples
To be able to run the exercises, you must first have iptables running as a service. On CentOS you can check with
```bash
yum list installed iptables-services
```
To install iptables
```bash
sudo yum install -y iptables-services
sudo systemctl start iptables
sudo systemctl enable iptables
```
Note that this will replace firewalld as the firewall service.

You can look at your existing connection tracking information with
```bash
cat /proc/net/nf_conntrack
ipv4     2 tcp      6 431999 ESTABLISHED src=10.0.1.242 dst=10.0.1.1 sport=22 dport=40272 src=10.0.1.1 dst=10.0.1.242 sport=40272 dport=22 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 zone=0 use=2
```
If you want to access this information in a more meaningful way, you can install the conntrack-tools
```bash
sudo yum install -y conntrack-tools
```
A few examples
```bash
conntrack -L
udp      17 160 src=10.0.1.242 dst=10.0.1.1 sport=37728 dport=53 src=10.0.1.1 dst=10.0.1.242 sport=53 dport=37728 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
tcp      6 431999 ESTABLISHED src=10.0.1.242 dst=10.0.1.1 sport=22 dport=40272 src=10.0.1.1 dst=10.0.1.242 sport=40272 dport=22 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
tcp      6 100 TIME_WAIT src=10.0.1.242 dst=144.217.237.129 sport=50738 dport=80 src=144.217.237.129 dst=10.0.1.242 sport=80 dport=50738 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
tcp      6 100 TIME_WAIT src=10.0.1.242 dst=144.217.237.129 sport=50736 dport=80 src=144.217.237.129 dst=10.0.1.242 sport=80 dport=50736 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
udp      17 160 src=10.0.1.242 dst=10.0.1.1 sport=50716 dport=53 src=10.0.1.1 dst=10.0.1.242 sport=53 dport=50716 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
conntrack v1.4.4 (conntrack-tools): 5 flow entries have been shown.

conntrack -L -p tcp --dport 80
tcp      6 80 TIME_WAIT src=10.0.1.242 dst=144.217.237.129 sport=50738 dport=80 src=144.217.237.129 dst=10.0.1.242 sport=80 dport=50738 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
tcp      6 80 TIME_WAIT src=10.0.1.242 dst=144.217.237.129 sport=50736 dport=80 src=144.217.237.129 dst=10.0.1.242 sport=80 dport=50736 [ASSURED] mark=0 secctx=system_u:object_r:unlabeled_t:s0 use=1
conntrack v1.4.4 (conntrack-tools): 2 flow entries have been shown.

conntrack -E -p tcp --dport 80
    [NEW] tcp      6 120 SYN_SENT src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 [UNREPLIED] src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022
 [UPDATE] tcp      6 60 SYN_RECV src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022
 [UPDATE] tcp      6 432000 ESTABLISHED src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022 [ASSURED]
 [UPDATE] tcp      6 120 FIN_WAIT src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022 [ASSURED]
 [UPDATE] tcp      6 30 LAST_ACK src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022 [ASSURED]
 [UPDATE] tcp      6 120 TIME_WAIT src=10.0.1.242 dst=93.184.216.34 sport=57022 dport=80 src=93.184.216.34 dst=10.0.1.242 sport=80 dport=57022 [ASSURED]
^C
conntrack v1.4.4 (conntrack-tools): 6 flow events have been shown.
```
Back to iptables, you can look at each one of the individual iptables:
```bash
iptables -t filter -L
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

iptables -t nat -L
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         

iptables -t raw -L
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

iptables -t mangle -L
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         

iptables -t security -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
```
With each command you can see the list of chains inside the table. 
We can also look into each chain:
```bash
iptables -L INPUT
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
ACCEPT     icmp --  anywhere             anywhere            
ACCEPT     all  --  anywhere             anywhere            
ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited
```
Note that when we don't specify a table, iptables will default to the *filter* table.
When looking at this output we can see that there's a REJECT at the last line, which means that any rule we appended to the end of this table would be ignored. 
To add new rules to the filter table, first we need to check line numbers
```bash
iptables -L --line-numbers
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
Then we add the rule (for example allow tcp traffic on port 80) *before* the REJECT:
```bash
iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT

iptables -L --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
1    ACCEPT     all  --  anywhere             anywhere             state RELATED,ESTABLISHED
2    ACCEPT     icmp --  anywhere             anywhere            
3    ACCEPT     all  --  anywhere             anywhere            
4    ACCEPT     tcp  --  anywhere             anywhere             state NEW tcp dpt:ssh
5    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:http
6    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination         
1    REJECT     all  --  anywhere             anywhere             reject-with icmp-host-prohibited

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination         

```
Notice how our rule was inserted before the REJECT, which means it will be evaluated properly.

This was just a quick example of how iptables work, if you want to dive deeper on it stay tunned for more advanced cases in future chapters of this training material.