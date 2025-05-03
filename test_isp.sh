#!/bin/bash

# Проверка прав
if [[ $EUID -ne 0 ]]; then
   echo "Script requires root rights!" 
   exit 1
fi

# Функция отображения меню
show_menu() {
    clear
    echo "System configuration menu:"
    echo "1. Enter interface data"
    echo "2. Configure network interfaces"
    echo "3. Setup Nftables"
    echo "4. Finalize configuration"
    echo "0. Exit"
    echo
    read -p "Choose option: " choice
}

# Функция валидации ввода
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Field cannot be empty. Input again."
        return 1
    fi
    return 0
}

# Функция сбора данных
collect_user_data() {
    # Сбор данных интерфейсов
    read -p "Input first interface name (DHCP): " isp_int1
    while ! validate_input "$isp_int1"; do
        read -p "Input first interface name (DHCP): " isp_int1
    done

    read -p "Input second interface name: " isp_int2
    while ! validate_input "$isp_int2"; do
        read -p "Input second interface name: " isp_int2
    done

    read -p "Input third interface name: " isp_int3
    while ! validate_input "$isp_int3"; do
        read -p "Input third interface name: " isp_int3
    done

    read -p "Input IP with mask for second interface (e.g., 192.168.1.1/24): " isp_ip_int2
    while ! validate_input "$isp_ip_int2"; do
        read -p "Input IP with mask for second interface: " isp_ip_int2
    done

    read -p "Input IP with mask for third interface (e.g., 192.168.2.1/24): " isp_ip_int3
    while ! validate_input "$isp_ip_int3"; do
        read -p "Input IP with mask for third interface: " isp_ip_int3
    done

    read -p "Input hostname (e.g., myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Input hostname: " isp_hostname
    done

    # Подтверждение введенных данных
    echo -e "\nEntered data:"
    echo "First interface (DHCP): $isp_int1"
    echo "Second interface: $isp_int2"
    echo "Third interface: $isp_int3"
    echo "Second interface IP: $isp_ip_int2"
    echo "Third interface IP: $isp_ip_int3"
    echo "Hostname: $isp_hostname"

    read -p "Data correct? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Script terminated. Input again."
        exit 1
    fi

    echo "Data saved"
}

# Функция настройки интерфейсов
configure_interfaces() {
    echo "Network interfaces configuration started..."

    # Расчет сетей
    addr2=$(echo "$isp_ip_int2" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask2=$(echo "$isp_ip_int2" | awk -F/ '{ print $2 }')
    net_int2="$addr2/$mask2"

    addr3=$(echo "$isp_ip_int3" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask3=$(echo "$isp_ip_int3" | awk -F/ '{ print $2 }')
    net_int3="$addr3/$mask3"

    # Создание конфигов
    mkdir -p "/etc/net/ifaces/$isp_int2" "/etc/net/ifaces/$isp_int3"

    echo "BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
" > "/etc/net/ifaces/$isp_int2/options"
    
    cp "/etc/net/ifaces/$isp_int2/options" "/etc/net/ifaces/$isp_int3/options"

    echo "$isp_ip_int2" > "/etc/net/ifaces/$isp_int2/ipv4address"
    echo "$isp_ip_int3" > "/etc/net/ifaces/$isp_int3/ipv4address"

    systemctl restart network
    apt-get update > /dev/null

    echo "Interfaces configured"
}

# Функция настройки Nftables
setup_nftables() {
    echo "Nftables configuration started..."

    # Включение пересылки
    sed -i "s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/" /etc/sysctl.conf

    # Установка пакета
    apt-get install -y nftables > /dev/null
    systemctl enable --now nftables

    # Создание правил
    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
    nft add rule ip nat postrouting ip saddr $net_int2 oifname "$isp_int1" counter masquerade
    nft add rule ip nat postrouting ip saddr $net_int3 oifname "$isp_int1" counter masquerade

    echo "Nftables configured"
}

# Функция завершения конфигурации
finalize_configuration() {
    echo "Final steps started..."

    # Настройка hostname
    echo "$isp_hostname" > /etc/hostname

    # Установка часового пояса
    apt-get install -y tzdata > /dev/null
    timedatectl set-timezone Asia/Novosibirsk

    # Перезагрузка служб
    systemctl restart nftables network

    # Проверка
    ping -c3 77.88.8.8 > /dev/null && echo "Internet connection works"
    nft list ruleset > /tmp/nft_config.txt

    echo "Configuration completed!"
}

# Функция выхода
exit_script() {
    echo "Exit requested..."
    exit 0
}

# Основной цикл меню
while true; do
    show_menu

    case "$choice" in
        1)
            collect_user_data
            ;;
        2)
            configure_interfaces
            ;;
        3)
            setup_nftables
            ;;
        4)
            finalize_configuration
            ;;
        0)
            exit_script
            ;;
        *)
            echo "Incorrect choice. Input again."
            sleep 1
            ;;
    esac
done
