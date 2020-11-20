Packet capture is a great way to gather evidence when you're troubleshooting or working through any kind of networking issue. They are also handy on grasping a better understanding of the traffic on your network.

## Packet Captures :: Overview
Packet captures intercept data between a source and a destination once it's in the network stack.
Picture for a moment a source (client) and a destination (server). 
- The packet capture will occur on an interface, for example in the client, server or even the router's network interface.
- The packet capture will observe all connection data flowing through that interface

**Capture Filters** are set prior to the capture, and used to reduce the size of the raw packet capture.
**Display Filters** are set during packet capture viewing, and used for viewing the packet capture.

A valid use case for capture filters is filtering out SSH traffic. Just by being logged in via SSH will generate a lot of noise that would unnecessarily inflate the size (and complexity) of the log file. 
With a *capture filter*, we can prevent that traffic that we're not interested in from ever making it into the log file. Then we can use a *display filter* to refine how we look at the file. For instance we can follow DNS queries, HTTP requests, etc and look at them in the context of each other.

## Packet Captures :: Capture filters
Both tcpdump and tshark (CLI version of wireshark) use the same backend and because of that can be used in the same way:
**tcpdump**
```bash
tcpdump -i eth0 -w capture.pcap
tcpdump -i eth0 -w capture.pcap and port not 22
```
**tshark**
```bash
tshark -i eth0 -w capture.pcap
tshark -i eth0 -w capture.pcap and port not 22
```

## Packet Captures :: Practical examples
Server1 at 10.0.1.10 running apache 
Client1 at 10.0.1.11
tcpdump, wireshark, telnet, bash-completion installed on both hosts

We start at Client1 but actually connecting to Client1 from Server1 via SSH.
If we run tcpdump with no arguments:
```bash
tcpdump
```
We should see a lot of stuff going on. That's because we are connected to this host via ssh. So if we filter out SSH (and also name resolution with the `n` flag):
```bash
tcpdump -ni eth0 and port not 22 
^C
```
Way less exciting, no activity because we have nothing going on besides the SSH. 

We can also filter the monitoring to a specific host:
```bash
tcpdump -ni eth0 and host 10.0.1.10
```
This is the same as running with no arguments because we only have this one host btw.

Let's generate some network activity with a script:
`traffic.sh`
```bash
#!/bin/bash
for i in {1..100}
  do
    curl 10.0.1.10 &> /dev/null
	sleep 5
  done
```
```bash
vim traffic.sh
chmod +x traffic.sh
nohup ./traffic.sh &
```
Now that we have some backgroud activity, it's time to run tcpdump again:
```bash
tcpdump -vv src 10.0.1.10 and not dst port 22
```
This runs tcpdump in the very verbose (vv) mode, monitoring traffic from 10.0.1.10 and not capturing SSH traffic.

The very verbose mode is kinda bloaty and we also forgot to disable name resolution. This kind of monitoring can create huge files very quickly and are not easy to be read so try to use it after having narrowed down what you're trying to analyze. For now, let's change back to what we were already doing:
```bash
tcpdump -ni eth0 and port not 22
```
Much easier on the eyes! Now we can start saving the output to a file instead of the screen:
```bash
tcpdump -ni eth0 and port not 22 -w capture.pcap
^C
ll
```
To read the file you use:
```bash
tcpdump -r capture.pcap
```
As you can see tcpdump is useful for both creating and reading capture packets. There is a lot of documentation available for it and you should look at this tool as a scalpel. It's very useful once you know where to make the incision.

Now let's take a look at tshark, wireshark's CLI tool for packet capturing:
```bash
tshark not port 22 -w /tmp/shark.pcap
```
We don't have any data flowing at the moment and the way chosen to do this and keep packet capture active was splitting the terminal with `screen`, so stop the capture if you have already started it. Install screen, start a session, split the window into two horizontal panes, run the command above on one pane and on the other:
```bash
dig google.com
ping google.com
ping 1.1.1.1
ping 10.0.1.10
telnet 10.0.1.10 80
FINDME!!!!!
```
At this point the packet capture was stopped and the proper permissions were given to the created file (`chmod 666 /tmp/shark.pcap`).
Then the exercise continues with the pcap file opened in the GUI version of wireshark

I'm not going into much here since we have 0 experience with wireshark but the main idea is to show
- the top pane has the summary of all captured packets
- the bottom pane has the details of a particular packet, collapsed by OSI layer
- you can apply a display filter on the top bar. examples (dns, http, icmp, dns or icmp) 
- if you click on the lenses it will open a search bar, where you can search for that elusive FINDME

Packet captures are a lot of fun, they are one of those things that are kind of mysterious until you start working with them a little more and then everything starts to come into place.
It's highly recommended to run some packet captures, download packet captures from the internet, use the ones provided with this training material.
Just use wireshark to look at them, play with them, do the sorting through the display filters, search for things, become familiar with the color scheme... you get the idea.

Wireshark is awesome and you should definitely give it a good chunk of your spare time until it becomes a part of your day-to-day.