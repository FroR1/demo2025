#!/bin/bash

# Проверка прав
if [[ $EUID -ne 0 ]]; then
   echo "Скрипт требует права root!" 
   exit 1
fi

# Функция отображения меню
show_menu() {
    clear
    echo "Меню настройки системы:"
    echo "1. Ввести данные интерфейсов"
    echo "2. Настроить сетевые интерфейсы"
    echo "3. Настроить Nftables"
    echo "4. Завершить конфигурацию"
    echo "0. Выход"
    echo
    read -p "Выберите пункт: " choice
}

# Функция валидации ввода
validate_input() {
    if [[ -z "$1" ]]; then
        echo "Ошибка: Поле не может быть пустым. Попробуйте снова."
        return 1
    fi
    return 0
}

# Функция сбора данных
collect_user_data() {
    # Сбор данных интерфейсов
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

    read -p "Введите IP с маской для второго интерфейса (например, 192.168.1.1/24): " isp_ip_int2
    while ! validate_input "$isp_ip_int2"; do
        read -p "Введите IP с маской для второго интерфейса: " isp_ip_int2
    done

    read -p "Введите IP с маской для третьего интерфейса (например, 192.168.2.1/24): " isp_ip_int3
    while ! validate_input "$isp_ip_int3"; do
        read -p "Введите IP с маской для третьего интерфейса: " isp_ip_int3
    done

    read -p "Введите hostname (например, myserver): " isp_hostname
    while ! validate_input "$isp_hostname"; do
        read -p "Введите hostname: " isp_hostname
    done

    # Подтверждение введенных данных
    echo -e "\nВведены следующие данные:"
    echo "Первый интерфейс (DHCP): $isp_int1"
    echo "Второй интерфейс: $isp_int2"
    echo "Третий интерфейс: $isp_int3"
    echo "IP второго интерфейса: $isp_ip_int2"
    echo "IP третьего интерфейса: $isp_ip_int3"
    echo "Hostname: $isp_hostname"

    read -p "Все верно? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Скрипт завершен. Попробуйте снова."
        exit 1
    fi

    echo "Данные сохранены"
}

# Функция настройки интерфейсов
configure_interfaces() {
    echo "Начало настройки сетевых интерфейсов..."

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

    echo "Настройка интерфейсов завершена"
}

# Функция настройки Nftables
setup_nftables() {
    echo "Начало настройки Nftables..."

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

    echo "Nftables настроен"
}

# Функция завершения конфигурации
finalize_configuration() {
    echo "Финальные шаги..."

    # Настройка hostname
    echo "$isp_hostname" > /etc/hostname

    # Установка часового пояса
    apt-get install -y tzdata > /dev/null
    timedatectl set-timezone Asia/Novosibirsk

    # Перезагрузка служб
    systemctl restart nftables network

    # Проверка
    ping -c3 77.88.8.8 > /dev/null && echo "Подключение к интернету работает"
    nft list ruleset > /tmp/nft_config.txt

    echo "Конфигурация завершена!"
}

# Функция выхода
exit_script() {
    echo "Выход из скрипта..."
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
            echo "Неверный выбор. Попробуйте снова."
            sleep 1
            ;;
    esac
done
