#!/bin/bash

isp_int1=$1
isp_int2=$2
isp_int3=$3
isp_ip_int2=$4
isp_ip_int3=$5
isp_hostname=$6

addr2=`echo $isp_ip_int2 | awk -F/ '{ print $1 }' | sed 's/.$/0/'`
mask2=`echo $isp_ip_int2 | awk -F/ '{ print $2 }'`
net_int2=$addr2/$mask2

addr3=`echo $isp_ip_int3 | awk -F/ '{ print $1 }' | sed 's/.$/0/'`
mask3=`echo $isp_ip_int3 | awk -F/ '{ print $2 }'`
net_int3=$addr3/$mask3


if (( $# < 6 )); then
	echo "Biven, nado tak:"
	echo "$0 interface1(dhcp) int2 int3 ip_addr_int2 ip_addr_int3 hostname"
	exit 1
fi

###
echo "Interface setup"
mkdir -p /etc/net/ifaces/$isp_int2
mkdir -p /etc/net/ifaces/$isp_int3

echo "BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
" > /etc/net/ifaces/$isp_int2/options

cp /etc/net/ifaces/$isp_int2/options /etc/net/ifaces/$isp_int3/options

echo "$isp_ip_int2" > /etc/net/ifaces/$isp_int2/ipv4address
echo "$isp_ip_int3" > /etc/net/ifaces/$isp_int3/ipv4address

systemctl restart network && apt-get update

###
echo "Time & hostname"
echo "$isp_hostname" > /etc/hostname
apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

###
echo "Nftables setup"

sed -i "s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/" /etc/net/sysctl.conf

apt-get update && apt-get install -y nftables
systemctl enable --now nftables

nft add table ip nat
nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
nft add rule ip nat postrouting ip saddr $net_int2 oifname "$isp_int1" counter masquerade
nft add rule ip nat postrouting ip saddr $net_int3 oifname "$isp_int1" counter masquerade

nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
systemctl restart nftables && systemctl restart network 

###
echo "Interfaces, nftables, timezone, hostname"
ping -c3 77.88.8.8 && nft list ruleset


exit 0
