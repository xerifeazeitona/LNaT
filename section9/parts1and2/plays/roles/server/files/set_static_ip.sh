#!/bin/bash
nmcli con show System\ eth0 | grep -i ipv4.address
nmcli con mod System\ eth0 ipv4.method manual ipv4.address $1 ipv4.gateway 10.0.1.1 ipv4.dns 10.0.1.1
systemctl restart network
nmcli con show System\ eth0 | grep -i ipv4.address
