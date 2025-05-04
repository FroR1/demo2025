#!/bin/bash

# Global variable declarations
declare -g isp_int1 isp_int2 isp_int3 isp_ip_int2 isp_ip_int3 isp_hostname
declare -g net_int2 net_int3

# Function to display usage instructions
show_usage() {
    echo "Usage: $0"
    echo "The script will prompt you for network interface and configuration details."
    echo "Follow the on-screen instructions."
}

# Function to validate input
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Error: Field cannot be empty. Please try again."
        return 1
    fi
    return 0
}

# Network calculation function
calculate_network() {
    local ip="$1"
    local mask="$2"
    
    IFS='.' read -r a b c d <<< "$ip"
    
    local bits=$((mask))
    local network_a network_b network_c network_d
    
    # Process first octet (8 bits)
    if (( bits >= 8 )); then
        network_a=$((a))
        bits=$((bits - 8))
    else
        network_a=$((a & (255 << (8 - bits))))
        bits=0
    fi
    
    # Second octet
    if (( bits >= 8 )); then
        network_b=$((b))
        bits=$((bits - 8))
    else
        network_b=$((b & (255 << (8 - bits))))
        bits=0
    fi
    
    # Third octet
    if (( bits >= 8 )); then
        network_c=$((c))
        bits=$((bits - 8))
    else
        network_c=$((c & (255 << (8 - bits))))
        bits=0
    fi
    
    # Fourth octet
    if (( bits > 0 )); then
        network_d=$((d & (255 << (8 - bits))))
    else
        network_d=0
    fi
    
    echo "$network_a.$network_b.$network_c.$network_d"
}

# Data collection function
collect_data() {
    show_usage

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

    read -p "Enter IP/subnet for second interface (e.g., 192.168.1.1/24): " isp_ip_int2
    while ! validate_input "$isp_ip_int2"; do
        read -p "Enter IP/subnet for second interface (e.g., 192.168.1.1/24): " isp_ip_int2
    done

    read -p "Enter IP/subnet for third interface (e.g., 192.168.2.1/24): " isp_ip_int3
    while ! validate_input "$isp_ip_int3"; do
        read -p "Enter IP/subnet for third interface (e.g., 192.168.2.1/24): " isp_ip_int3
    done

    read -p "Enter hostname (e.g., myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Enter hostname (e.g., myserver): " isp_hostname
    done

    # Calculate networks using new function
    addr2=$(echo "$isp_ip_int2" | awk -F/ '{print $1}')
    mask2=$(echo "$isp_ip_int2" | awk -F/ '{print $2}')
    net_ip2=$(calculate_network "$addr2" "$mask2")
    net_int2="$net_ip2/$mask2"

    addr3=$(echo "$isp_ip_int3" | awk -F/ '{print $1}')
    mask3=$(echo "$isp_ip_int3" | awk -F/ '{print $2}')
    net_ip3=$(calculate_network "$addr3" "$mask3")
    net_int3="$net_ip3/$mask3"

    # Confirmation
    echo "You entered:"
    echo "First interface (DHCP): $isp_int1"
    echo "Second interface: $isp_int2"
    echo "Third interface: $isp_int3"
    echo "Second interface IP: $isp_ip_int2"
    echo "Third interface IP: $isp_ip_int3"
    echo "Hostname: $isp_hostname"
    echo "Calculated networks:"
    echo "Second interface network: $net_int2"
    echo "Third interface network: $net_int3"

    read -p "Proceed with these settings? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting configuration"
        exit 1
    fi
}

# Interface configuration function
configure_interfaces() {
    if [[ -z "$isp_int2" || -z "$isp_ip_int2" ]]; then
        echo "Error: Please collect data first (option 1)"
        return
    fi

    echo "Configuring network interfaces..."

    mkdir -p "/etc/net/ifaces/$isp_int2"
    mkdir -p "/etc/net/ifaces/$isp_int3"

    cat <<EOF > "/etc/net/ifaces/$isp_int2/options"
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF

    cp "/etc/net/ifaces/$isp_int2/options" "/etc/net/ifaces/$isp_int3/options"

    echo "$isp_ip_int2" > "/etc/net/ifaces/$isp_int2/ipv4address"
    echo "$isp_ip_int3" > "/etc/net/ifaces/$isp_int3/ipv4address"

    systemctl restart network && apt-get update
}

# Time and hostname configuration
configure_time() {
    echo "$isp_hostname" > /etc/hostname
    apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk
}

# Nftables configuration function
configure_nftables() {
    if [[ -z "$net_int2" || -z "$net_int3" ]]; then
        echo "Error: Please collect data first (option 1)"
        return
    fi

    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf

    apt-get update && apt-get install -y nftables
    systemctl enable --now nftables

    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
    nft add rule ip nat postrouting ip saddr "$net_int2" oifname "$isp_int1" counter masquerade
    nft add rule ip nat postrouting ip saddr "$net_int3" oifname "$isp_int1" counter masquerade

    nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
    systemctl restart nftables && systemctl restart network
}

# Function to check functionality
check_function() {
    ping -c3 77.88.8.8 && nft list ruleset
}

# Menu display function
show_menu() {
    echo "Menu:"
    echo "1. Collect configuration data"
    echo "2. Configure network interfaces"
    echo "3. Configure hostname and timezone"
    echo "4. Configure Nftables"
    echo "5. Check configuration"
    echo "0. Exit"
    read -p "Select an option: " choice
    case $choice in
        1) collect_data ;;
        2) configure_interfaces ;;
        3) configure_time ;;
        4) configure_nftables ;;
        5) check_function ;;
        0) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
}

# Main execution loop
main() {
    while true; do
        show_menu
    done
}

main
