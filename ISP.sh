#!/bin/bash
apt-get update
apt-get install nftables -y
echo "ISP" > '/etc/hostname'
mkdir '/etc/net/ifaces/ens224' '/etc/net/ifaces/ens256'
touch '/etc/net/ifaces/ens224/options' '/etc/net/ifaces/ens224/ipv4adress'
touch '/etc/net/ifaces/ens256/options' '/etc/net/ifaces/ens256/ipv4adress'
echo -e "TYPE=eth\nBOOTPROTO=static\nipv4address=yes\nDISABLED=no" > '/etc/net/ifaces/ens224/options'
echo -e "TYPE=eth\nBOOTPROTO=static\nipv4address=yes\nDISABLED=no" > '/etc/net/ifaces/ens224/options'
echo "172.16.5.1/28" > '/etc/net/ifaces/ens224/ipv4address'
echo "172.16.4.1/28" > '/etc/net/ifaces/ens256/ipv4address'
systemctl restart network
ip a
nft add table ip nat
nft add chain ip nat postrouting '{type nat hook postrouting priority 0;}'
nft add rule ip nat postrouting ip saddrr 172.16.5.0/28 oifname "ens192" counter masquerade
nft add rule ip nat postrouting ip saddrr 172.16.4.0/28 oifname "ens192" counter masquerade
nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
printf "Не забудь включить форвардинг в /etc/net/sysctl.conf"

