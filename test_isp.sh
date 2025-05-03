#!/bin/bash

# Объявление глобальных переменных
declare -g isp_int1 isp_int2 isp_int3 isp_ip_int2 isp_ip_int3 isp_hostname
declare -g net_masq2 net_masq3

# Функция отображения инструкций
show_usage() {
    echo "Usage: $0"
    echo "Скрипт запросит данные о сетевых интерфейсах и настройках."
    echo "Следуйте инструкциям на экране."
}

# Функция проверки ввода
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Error: Field cannot be empty. Please try again."
        return 1
    fi
    return 0
}

# Функция сбора данных
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

    # Новые поля ввода для маскарада
    read -p "Enter network for masquerade (second interface, e.g., 192.168.1.0/24): " net_masq2
    while ! validate_input "$net_masq2"; do
        read -p "Enter network for masquerade (second interface, e.g., 192.168.1.0/24): " net_masq2
    done

    read -p "Enter network for masquerade (third interface, e.g., 192.168.2.0/24): " net_masq3
    while ! validate_input "$net_masq3"; do
        read -p "Enter network for masquerade (third interface, e.g., 192.168.2.0/24): " net_masq3
    done

    read -p "Enter hostname (e.g., myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Enter hostname (e.g., myserver): " isp_hostname
    done

    # Подтверждение данных
    echo "You entered:"
    echo "First interface (DHCP): $isp_int1"
    echo "Second interface: $isp_int2"
    echo "Third interface: $isp_int3"
    echo "Second interface IP: $isp_ip_int2"
    echo "Third interface IP: $isp_ip_int3"
    echo "Masquerade network (2): $net_masq2"
    echo "Masquerade network (3): $net_masq3"
    echo "Hostname: $isp_hostname"

    read -p "Proceed with these settings? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting configuration"
        exit 1
    fi
}

# Настройка интерфейсов
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

# Настройка времени и hostname
configure_time() {
    echo "$isp_hostname" > /etc/hostname
    apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk
}

# Настройка Nftables
configure_nftables() {
    if [[ -z "$net_masq2" || -z "$net_masq3" ]]; then
        echo "Error: Please collect data first (option 1)"
        return
    fi

    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf

    apt-get update && apt-get install -y nftables
    systemctl enable --now nftables

    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
    nft add rule ip nat postrouting ip saddr "$net_masq2" oifname "$isp_int1" counter masquerade
    nft add rule ip nat postrouting ip saddr "$net_masq3" oifname "$isp_int1" counter masquerade

    nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
    systemctl restart nftables && systemctl restart network
}

# Проверка работы
check_function() {
    ping -c3 77.88.8.8 && nft list ruleset
}

# Меню выбора
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

# Основная функция
main() {
    while true; do
        show_menu
    done
}

main
