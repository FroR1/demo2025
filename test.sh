#!/bin/bash

# Funktsiya dlya vyvoda instruktsiy po ispolzovaniyu
usage() {
    echo "Ispolzovanie: $0 <interfeys1> <interfeys2> <interfeys3> <ip_addr_int2> <ip_addr_int3> <imya_khosta>"
    echo "Primer: $0 eth0 eth1 eth2 192.168.1.1/24 192.168.2.1/24 moykhost"
    echo "Opisanie peremennykh:"
    echo "  interfeys1  - Imya pervogo interfeysa (obychno dlya DHCP)"
    echo "  interfeys2  - Imya vtorogo interfeysa"
    echo "  interfeys3  - Imya tretego interfeysa"
    echo "  ip_addr_int2 - IP-adres i maska vtorogo interfeysa (naprimer, 192.168.1.1/24)"
    echo "  ip_addr_int3 - IP-adres i maska tretego interfeysa (naprimer, 192.168.2.1/24)"
    echo "  imya_khosta - Imya khosta"
    exit 1
}

# Funktsiya proverki korrektnosti vkhodnykh dannykh
validate_input() {
    local int1=$1
    local int2=$2
    local int3=$3
    local ip2=$4
    local ip3=$5
    local hostname=$6

    # Proverka kolichestva argumentov
    if [ $# -lt 6 ]; then
        echo "Oshibka: nedostatochno argumentov."
        usage
    fi

    # Proverka, chto interfeysy ne pustye
    for int in "$int1" "$int2" "$int3"; do
        if [ -z "$int" ]; then
            echo "Oshibka: imya interfeysa ne mozhet byt pustym."
            usage
        fi
    done

    # Proverka formata IP-adresov (prostaya proverka na nalichie / i tsifr)
    for ip in "$ip2" "$ip3"; do
        if ! echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'; then
            echo "Oshibka: IP-adres $ip imeet nevernyy format (ozhidaetsya, naprimer, 192.168.1.1/24)."
            usage
        fi
    done

    # Proverka imeni khosta (ne pustoe i soderzhit tolko dopustimye simvoly)
    if ! echo "$hostname" | grep -qE '^[a-zA-Z0-9-]+$'; then
        echo "Oshibka: imya khosta $hostname soderzhit nedopustimye simvoly ili pustoe."
        usage
    fi

    echo "Vse vkhodnye dannye korrektny:"
    echo "  interfeys1: $int1"
    echo "  interfeys2: $int2"
    echo "  interfeys3: $int3"
    echo "  ip_addr_int2: $ip2"
    echo "  ip_addr_int3: $ip3"
    echo "  imya_khosta: $hostname"
}

# Osnovnoy skript
# Prisvaivanie peremennykh
isp_int1="$1"
isp_int2="$2"
isp_int3="$3"
isp_ip_int2="$4"
isp_ip_int3="$5"
isp_hostname="$6"

# Proverka vkhodnykh dannykh
validate_input "$isp_int1" "$isp_int2" "$isp_int3" "$isp_ip_int2" "$isp_ip_int3" "$isp_hostname"

# Vychislenie adresov i masok
addr2=$(echo "$isp_ip_int2" | awk -F/ '{print $1}' | sed 's/\.[0-9]\+$/.0/')
mask2=$(echo "$isp_ip_int2" | awk -F/ '{print $2}')
net_int2="$addr2/$mask2"

addr3=$(echo "$isp_ip_int3" | awk -F/ '{print $1}' | sed 's/\.[0-9]\+$/.0/')
mask3=$(echo "$isp_ip_int3" | awk -F/ '{print $2}')
net_int3="$addr3/$mask3"

# Nastroyka interfeysov
echo "Nastroyka interfeysa"
mkdir -p "/etc/net/ifaces/$isp_int2"
mkdir -p "/etc/net/ifaces/$isp_int3"

cat << EOF > "/etc/net/ifaces/$isp_int2/options"
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF

cp "/etc/net/ifaces/$isp_int2/options" "/etc/net/ifaces/$isp_int3/options"
echo "$isp_ip_int2" > "/etc/net/ifaces/$isp_int2/ipv4address"
echo "$isp_ip_int3" > "/etc/net/ifaces/$isp_int3/ipv4address"

systemctl restart network && apt-get update

# Nastroyka vremeni i imeni khosta
echo "Vremya i imya khosta"
echo "$isp_hostname" > /etc/hostname
apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

# Nastroyka nftables
echo "Nastroyka nftables"
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
apt-get update && apt-get install -y nftables
systemctl enable --now nftables

nft add table ip nat
nft add chain ip nat postrouting '{ type nat hook postrouting priority 0 ; }'
nft add rule ip nat postrouting ip saddr "$net_int2" oifname "$isp_int1" counter masquerade
nft add rule ip nat postrouting ip saddr "$net_int3" oifname "$isp_int1" counter masquerade
nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft

systemctl restart nftables && systemctl restart network

# Proverka
echo "Interfeysy, nftables, chasovoy poyas, imya khosta nastroeny"
ping -c3 77.88.8.8 && nft list ruleset

exit 0
