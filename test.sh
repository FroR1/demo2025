#!/bin/bash

# Function to display usage instructions
show_usage() {
    echo "Usage: $0"
    echo "The script will prompt you for information about network interfaces and settings."
    echo "Please follow the on-screen instructions."
}

# Function to validate input
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Error: Field cannot be empty. Please try again."
        return 1
    fi
    return 0
}

# Main script logic
main() {
    # Display instructions
    show_usage

    # Prompt user for input
    read -p "Enter the name of the first interface (DHCP): " isp_int1
    while ! validate_input "$isp_int1"; do
        read -p "Enter the name of the first interface (DHCP): " isp_int1
    done

    read -p "Enter the name of the second interface: " isp_int2
    while ! validate_input "$isp_int2"; do
        read -p "Enter the name of the second interface: " isp_int2
    done

    read -p "Enter the name of the third interface: " isp_int3
    while ! validate_input "$isp_int3"; do
        read -p "Enter the name of the third interface: " isp_int3
    done

    read -p "Enter the IP address with subnet mask for the second interface (e.g., 192.168.1.1/24): " isp_ip_int2
    while ! validate_input "$isp_ip_int2"; do
        read -p "Enter the IP address with subnet mask for the second interface (e.g., 192.168.1.1/24): " isp_ip_int2
    done

    read -p "Enter the IP address with subnet mask for the third interface (e.g., 192.168.2.1/24): " isp_ip_int3
    while ! validate_input "$isp_ip_int3"; do
        read -p "Enter the IP address with subnet mask for the third interface (e.g., 192.168.2.1/24): " isp_ip_int3
    done

    read -p "Enter the hostname (e.g., myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Enter the hostname (e.g., myserver): " isp_hostname
    done

    # Confirm input
    echo "You entered the following data:"
    echo "First interface (DHCP): $isp_int1"
    echo "Second interface: $isp_int2"
    echo "Third interface: $isp_int3"
    echo "IP address of the second interface: $isp_ip_int2"
    echo "IP address of the third interface: $isp_ip_int3"
    echo "Hostname: $isp_hostname"

    read -p "Is everything correct? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Script terminated. Please try again."
        exit 1
    fi

    # Perform main script logic
    echo "Starting system configuration..."

    # Calculate networks for interfaces
    addr2=$(echo "$isp_ip_int2" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask2=$(echo "$isp_ip_int2" | awk -F/ '{ print $2 }')
    net_int2="$addr2/$mask2"

    addr3=$(echo "$isp_ip_int3" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask3=$(echo "$isp_ip_int3" | awk -F/ '{ print $2 }')
    net_int3="$addr3/$mask3"

    # Configure interfaces
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

    # Configure time and hostname
    echo "$isp_hostname" > /etc/hostname
    apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

    # Configure Nftables
    sed -i "s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/" /etc/net/sysctl.conf

    apt-get update && apt-get install -y nftables
    systemctl enable --now nftables

    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
    nft add rule ip nat postrouting ip saddr $net_int2 oifname "$isp_int1" counter masquerade
    nft add rule ip nat postrouting ip saddr $net_int3 oifname "$isp_int1" counter masquerade

    nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
    systemctl restart nftables && systemctl restart network

    # Verify functionality
    ping -c3 77.88.8.8 && nft list ruleset

    echo "Configuration completed!"
    exit 0
}

# Run the main script
main
