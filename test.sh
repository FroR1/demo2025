#!/bin/bash

# Функция для вывода инструкций
show_usage() {
    echo "Использование: $0"
    echo "Скрипт запросит у вас информацию о сетевых интерфейсах и настройках."
    echo "Пожалуйста, следуйте инструкциям на экране."
}

# Функция для проверки ввода данных
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Ошибка: Поле не может быть пустым. Пожалуйста, повторите ввод."
        return 1
    fi
    return 0
}

# Основной скрипт
main() {
    # Выводим инструкции
    show_usage

    # Запрашиваем данные у пользователя
    read -p "Введите имя первого интерфейса (DHCP): " isp_int1
    while ! validate_input "$isp_int1"; do
        read -p "Введите имя первого интерфейса (DHCP): " isp_int1
    done

    read -p "Введите имя второго интерфейса: " isp_int2
    while ! validate_input "$isp_int2"; do
        read -p "Введите имя второго интерфейса: " isp_int2
    done

    read -p "Введите имя третьего интерфейса: " isp_int3
    while ! validate_input "$isp_int3"; do
        read -p "Введите имя третьего интерфейса: " isp_int3
    done

    read -p "Введите IP-адрес с маской для второго интерфейса (например, 192.168.1.1/24): " isp_ip_int2
    while ! validate_input "$isp_ip_int2"; do
        read -p "Введите IP-адрес с маской для второго интерфейса (например, 192.168.1.1/24): " isp_ip_int2
    done

    read -p "Введите IP-адрес с маской для третьего интерфейса (например, 192.168.2.1/24): " isp_ip_int3
    while ! validate_input "$isp_ip_int3"; do
        read -p "Введите IP-адрес с маской для третьего интерфейса (например, 192.168.2.1/24): " isp_ip_int3
    done

    read -p "Введите имя хоста (например, myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Введите имя хоста (например, myserver): " isp_hostname
    done

    # Подтверждение ввода
    echo "Вы ввели следующие данные:"
    echo "Первый интерфейс (DHCP): $isp_int1"
    echo "Второй интерфейс: $isp_int2"
    echo "Третий интерфейс: $isp_int3"
    echo "IP-адрес второго интерфейса: $isp_ip_int2"
    echo "IP-адрес третьего интерфейса: $isp_ip_int3"
    echo "Имя хоста: $isp_hostname"

    read -p "Все верно? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Скрипт завершен. Повторите попытку."
        exit 1
    fi

    # Выполняем основную логику скрипта
    echo "Начинаем настройку системы..."

    # Вычисляем сети для интерфейсов
    addr2=$(echo "$isp_ip_int2" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask2=$(echo "$isp_ip_int2" | awk -F/ '{ print $2 }')
    net_int2="$addr2/$mask2"

    addr3=$(echo "$isp_ip_int3" | awk -F/ '{ print $1 }' | sed 's/.$/0/')
    mask3=$(echo "$isp_ip_int3" | awk -F/ '{ print $2 }')
    net_int3="$addr3/$mask3"

    # Настройка интерфейсов
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

    # Настройка времени и имени хоста
    echo "$isp_hostname" > /etc/hostname
    apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

    # Настройка Nftables
    sed -i "s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/" /etc/net/sysctl.conf

    apt-get update && apt-get install -y nftables
    systemctl enable --now nftables

    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
    nft add rule ip nat postrouting ip saddr $net_int2 oifname "$isp_int1" counter masquerade
    nft add rule ip nat postrouting ip saddr $net_int3 oifname "$isp_int1" counter masquerade

    nft list ruleset | tail -n7 | tee -a /etc/nftables/nftables.nft
    systemctl restart nftables && systemctl restart network

    # Проверка работы
    ping -c3 77.88.8.8 && nft list ruleset

    echo "Настройка завершена!"
    exit 0
}

# Запуск основного скрипта
main