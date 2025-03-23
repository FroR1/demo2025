#!/bin/bash

br_rtr_int1=$1
br_rtr_int2=$2
br_rtr_ip_int2=$3
hq_rtr_ip_int1=$4

addr2=`echo $br_rtr_ip_int2 | awk -F/ '{ print $1 }' | sed 's/.$/0/'`
mask2=`echo $br_rtr_ip_int2 | awk -F/ '{ print $2 }'`
net_int2=$addr2/$mask2

ip_int1=`cat /etc/net/ifaces/$br_rtr_int1/ipv4address`

br_rtr_iptun=$5
br_rtr_hostname=$6
rtr_user=$7
rtr_uid=$8


if (( $# < 8 )); then
	echo "Бивень, надо так:"
	echo "$0 interface1 int2 ip_addr_int2 hq-rtr-ip-int1 iptun_addr hostname user uid"
	exit 1
fi

###
echo "Пинаем интерфейсы"
mkdir -p /etc/net/ifaces/$br_rtr_int2
mkdir -p /etc/net/ifaces/tun1

echo "BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
" > /etc/net/ifaces/$br_rtr_int2/options

echo "TYPE=iptun
TUNTYPE=gre
TUNLOCAL=$ip_int1
TUNREMOTE=$hq_rtr_ip_int1
TUNOPTIONS='ttl 64'
HOST=$br_rtr_int1
" > /etc/net/ifaces/tun1/options

echo "$br_rtr_ip_int2" > /etc/net/ifaces/$br_rtr_int2/ipv4address
echo "$br_rtr_iptun" > /etc/net/ifaces/tun1/ipv4address

systemctl restart network && ping -c4 77.88.8.8

###
echo "Время + хост"
echo "$br_rtr_hostname" > /etc/hostname

apt-get update && apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

###
echo "Настраиваем nftables"
sed -i "s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/" /etc/net/sysctl.conf

apt-get update && apt-get install -y nftables && systemctl enable --now nftables

nft add table ip nat
nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
nft add rule ip nat postrouting ip saddr $net_int2 oifname "$br_rtr_int1" counter masquerade

nft list ruleset | tail -n6 | tee -a /etc/nftables/nftables.nft
systemctl restart nftables && systemctl restart network

###
echo "Создаём пользователя. Пароль пишем ручками. Ибо я устал. =-="
adduser $rtr_user -u $rtr_uid
echo "$rtr_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
usermod -aG wheel $rtr_user
passwd $rtr_user

###
echo "Настроили интерфейсы, nftables, время, создали пользователя, поменяли имя хоста"
ping -c4 77.88.8.8 && nft list ruleset

exit 0
