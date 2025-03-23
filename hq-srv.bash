#!/bin/bash

int1=$1
hq_srv_hostname=$2
srv_user=$3
srv_uid=$4
vid_srv=$5
vid_mngt=$6
ip_mngt=$7
port=$8

if (( $# < 8 )); then
	echo "Бивень, надо так:"
	echo "$0 int1 hq-srv_hostname srv_user srv_uid vid_srv vid_managment ip_mngt port"
	exit 1
fi

echo "Пинаем управленьческий int"
mkdir /etc/net/ifaces/$int1.$vid_mngt
cp /etc/net/ifaces/$int1/options /etc/net/ifaces/$int1.$vid_mngt/options
sed -i "s/VID=$vid_srv/VID=$vid_nmgt/" /etc/net/ifaces/$int1.$vid_mngt/options
echo "$ip_mngt" > /etc/net/ifaces//etc/net/ifaces/$int1.$vid_mngt/ipv4address

###
echo "Меняем имя хоста, настраиваем время"
echo "$hq_srv_hostname" > /etc/hostname
apt-get update && apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

###
echo "Настраиваем удалённый доступ" 
echo "Authorized access only" > /etc/banner
echo "Banner /etc/banner" >> /etc/openssh/sshd_config

sed -i "s/#Port 22/Port $port/g" /etc/openssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/openssh/sshd_config
echo "AllowUsers $srv_user" >> /etc/openssh/sshd_config

systemctl restart sshd

###
echo "Создаём пользователя. Пароль пишем ручками. Ибо я устал. =-="
adduser $srv_user -u $srv_uid
echo "$srv_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
usermod -aG wheel $srv_user
passwd $srv_user


exit 0


###
echo "Настройка DNS"
apt-get update && apt-get install bind bind-utils && systemctl enable --now bind

sed -i 's/listen-on { 127.0.0.0; }/listen-on { any; }/' /etc/bind/options.conf
sed -i 's\listen-on6\//listen-on-v6\' /etc/bind/options.conf
sed -i 's/forwarders blabla/forwarders { 77.88.8.8; }/' /etc/bind/options.conf
sed -i 's/allow-query { bla; }/allow-query { any; }/' /etc/bind/options.conf
