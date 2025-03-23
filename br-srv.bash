#!/bin/bash

br_srv_hostname=$1
srv_user=$2
srv_uid=$3
port=$4

if (( $# < 4 )); then
	echo "Бивень, надо так:"
	echo "$0 br-srv_hostname srv_user srv_uid port"
	exit 1
fi

###
echo "Меняем имя хоста, настраиваем время"
echo "$br_srv_hostname" > /etc/hostname
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
