#!/bin/bash
nmcli con mod System\ eth0 ipv4.method manual ipv4.address 10.0.1.10/24 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
#nmcli con mod Wired\ connection\ 1 ipv4.method manual ipv4.address 10.0.1.20 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
systemctl restart network
nmcli
