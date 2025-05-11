#!/bin/bash

# Function to calculate network address from IP and mask
function get_network() {
    local ip_with_mask=$1
    local ip=$(echo $ip_with_mask | cut -d'/' -f1)
    local prefix=$(echo $ip_with_mask | cut -d'/' -f2)
    local netmask=$(ipcalc -m $ip_with_mask | grep Netmask | awk '{print $2}')
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    IFS='.' read -r m1 m2 m3 m4 <<< "$netmask"
    local n1=$((i1 & m1))
    local n2=$((i2 & m2))
    local n3=$((i3 & m3))
    local n4=$((i4 & m4))
    echo "$n1.$n2.$n3.$n4"
}

# Function to check if timezone exists
function check_timezone() {
    local tz=$1
    timedatectl list-timezones | grep -Fxq "$tz"
    return $?
}

# Function to display animated menu
function display_menu() {
    # Install figlet if not present (run once manually: sudo apt-get install figlet)
    if ! command -v figlet &> /dev/null; then
        echo "Please install figlet (sudo apt-get install figlet) for animation."
        return 1
    fi

    # Animation with blinking title
    for i in {1..3}; do
        clear
        figlet -c "ISP Config"
        sleep 0.5
        clear
        sleep 0.5
    done
    clear
    figlet -c "ISP Config"
    echo "---------------------"
    echo "1. Enter or edit your data"
    echo "2. Configure interfaces (except ens192)"
    echo "3. Configure nftables"
    echo "4. Set hostname"
    echo "5. Check configuration status"
    echo "6. Remove configurations"
    echo "7. Show help"
    echo "0. Exit"
}

# Function to check configuration status
function check_config() {
    local config=$1
    case $config in
        "hostname")
            if [ -f /etc/hostname ] && [ "$(cat /etc/hostname)" = "$HOSTNAME" ]; then
                echo "yes"
            elif [ -f /etc/hostname ]; then
                echo "no"
            else
                echo "error"
            fi
            ;;
        "interfaces")
            if [ -d /etc/net/ifaces/$INTERFACE_HQ ] && [ -d /etc/net/ifaces/$INTERFACE_BR ]; then
                if grep -q "BOOTPROTO=static" /etc/net/ifaces/$INTERFACE_HQ/options && \
                   grep -q "BOOTPROTO=static" /etc/net/ifaces/$INTERFACE_BR/options; then
                    echo "yes"
                else
                    echo "no"
                fi
            else
                echo "error"
            fi
            ;;
        "nftables")
            if systemctl is-active --quiet nftables && nft list ruleset | grep -q "masquerade"; then
                echo "yes"
            elif systemctl is-active --quiet nftables; then
                echo "no"
            else
                echo "not configured"
            fi
            ;;
        "time_zone")
            local current_tz=$(timedatectl show | grep Timezone | cut -d'=' -f2)
            if [ "$current_tz" = "$TIME_ZONE" ]; then
                echo "yes"
            elif [ -n "$current_tz" ]; then
                echo "no"
            else
                echo "not configured"
            fi
            ;;
        *)
            echo "error"
            ;;
    esac
}

# Function to validate IP address format
function validate_ip() {
    local ip_with_mask=$1
    if [[ $ip_with_mask =~ ^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/([0-9]|[12][0-9]|3[0-2])$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to display and edit data
function edit_data() {
    echo "Entering edit_data function..." # Отладочный вывод
    while true; do
        clear
        echo "Current Data:"
        echo "1. HQ interface name: $INTERFACE_HQ"
        echo "2. BR interface name: $INTERFACE_BR"
        echo "3. IP for HQ interface: $IP_HQ"
        echo "4. IP for BR interface: $IP_BR"
        echo "5. Hostname: $HOSTNAME"
        echo "6. Set time zone: $TIME_ZONE"
        echo "7. Enter new data"
        echo "8. Show network map"
        echo "0. Back to main menu"
        read -p "Enter the number to edit or 6 to set time zone or 7 to enter new data (0 to exit): " edit_choice
        case $edit_choice in
            1)
                read -p "Enter new HQ interface name: " INTERFACE_HQ
                ;;
            2)
                read -p "Enter new BR interface name: " INTERFACE_BR
                ;;
            3)
                while true; do
                    read -p "Enter new IP for HQ interface (e.g., 172.16.4.1/28): " IP_HQ
                    if validate_ip "$IP_HQ"; then
                        break
                    else
                        echo "Invalid IP format. Please use format like 172.16.4.1/28 (octets 0-255, prefix 0-32)."
                        read -p "Press Enter to try again..."
                    fi
                done
                ;;
            4)
                while true; do
                    read -p "Enter new IP for BR interface (e.g., 172.16.5.1/28): " IP_BR
                    if validate_ip "$IP_BR"; then
                        break
                    else
                        echo "Invalid IP format. Please use format like 172.16.5.1/28 (octets 0-255, prefix 0-32)."
                        read -p "Press Enter to try again..."
                    fi
                done
                ;;
            5)
                read -p "Enter new hostname: " HOSTNAME
                ;;
            6)
                while true; do
                    read -p "Enter new time zone (e.g., Asia/Novosibirsk): " TIME_ZONE
                    if check_timezone "$TIME_ZONE"; then
                        timedatectl set-timezone "$TIME_ZONE"
                        if [ $? -eq 0 ]; then
                            echo "Time zone set to $TIME_ZONE."
                            break
                        else
                            echo "Error setting time zone. Please try again."
                        fi
                    else
                        echo "Invalid or not installed time zone: $TIME_ZONE."
                        echo "Use 'timedatectl list-timezones' to see valid options."
                    fi
                    read -p "Press Enter to try again..."
                done
                ;;
            7)
                read -p "Enter HQ interface name: " INTERFACE_HQ
                read -p "Enter BR interface name: " INTERFACE_BR
                while true; do
                    read -p "Enter IP for HQ interface (e.g., 172.16.4.1/28): " IP_HQ
                    if validate_ip "$IP_HQ"; then
                        break
                    else
                        echo "Invalid IP format. Please use format like 172.16.4.1/28 (octets 0-255, prefix 0-32)."
                        read -p "Press Enter to try again..."
                    fi
                done
                while true; do
                    read -p "Enter IP for BR interface (e.g., 172.16.5.1/28): " IP_BR
                    if validate_ip "$IP_BR"; then
                        break
                    else
                        echo "Invalid IP format. Please use format like 172.16.5.1/28 (octets 0-255, prefix 0-32)."
                        read -p "Press Enter to try again..."
                    fi
                done
                read -p "Enter hostname: " HOSTNAME
                ;;
            8)
                # Display network map
                clear
                echo "=== Network Map ==="
                echo "  +----------------+"
                echo "  |   Internet     |"
                echo "  +----------------+"
                echo "          |"
                echo "          | (ens192)"
                echo "          |"
                echo "  +----------------+    +----------------+"
                echo "  | $INTERFACE_HQ  |----| $INTERFACE_BR  |"
                echo "  | IP: $IP_HQ    |    | IP: $IP_BR    |"
                echo "  +----------------+    +----------------+"
                echo "Press Enter to return..."
                read
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid choice. Returning to main menu."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to remove configurations with backup
function remove_config() {
    local config=$1
    case $config in
        "interfaces")
            mkdir -p /etc/isp_backup/$(date +%Y%m%d_%H%M%S)
            cp -r /etc/net/ifaces/* /etc/isp_backup/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null
            rm -rf /etc/net/ifaces/$INTERFACE_HQ
            rm -rf /etc/net/ifaces/$INTERFACE_BR
            echo "Interface configurations removed. Backup created in /etc/isp_backup/$(date +%Y%m%d_%H%M%S)/."
            ;;
        "nftables")
            mkdir -p /etc/isp_backup/$(date +%Y%m%d_%H%M%S)
            cp -r /etc/nftables/* /etc/isp_backup/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null
            nft flush ruleset
            rm -f /etc/nftables/nftables.nft
            rm -f /etc/nftables/nftables.nft.bak
            rm -f /etc/nftables/nftables.nft.*
            systemctl stop nftables
            echo "nftables configurations and backups removed. Backup created in /etc/isp_backup/$(date +%Y%m%d_%H%M%S)/."
            ;;
        "time_zone")
            timedatectl set-timezone UTC
            echo "Time zone reset to UTC."
            ;;
        "hostname")
            echo "localhost" > /etc/hostname
            hostnamectl set-hostname localhost
            echo "Hostname reset to localhost."
            ;;
        "all")
            remove_config "interfaces"
            remove_config "nftables"
            remove_config "time_zone"
            remove_config "hostname"
            echo "All configurations removed."
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Function to display help
function show_help() {
    clear
    echo "ISP Configuration Script Help"
    echo "1. Enter or edit your data: Set or modify interface names, IPs, hostname, and time zone."
    echo "   - IPs should be in format like 172.16.4.1/28 (octets 0-255, prefix 0-32)."
    echo "2. Configure interfaces: Sets up interfaces (except ens192) with static IPs."
    echo "3. Configure nftables: Sets up NAT with masquerade for specified IPs."
    echo "4. Set hostname: Apply the specified hostname."
    echo "5. Check configuration status: Shows current status of all settings."
    echo "6. Remove configurations: Deletes configurations with backup."
    echo "7. Show help: Displays this help message."
    echo "0. Exit: Exits the script."
    read -p "Press Enter to return to menu..."
}

# Default values
INTERFACE_HQ="ens224"
INTERFACE_BR="ens256"
IP_HQ="172.16.4.1/28"
IP_BR="172.16.5.1/28"
HOSTNAME="isp"
TIME_ZONE="Asia/Novosibirsk"

# Main loop
while true; do
    display_menu
    read -p "Enter your choice: " choice
    case $choice in
        1)
            echo "Calling edit_data..." # Отладочный вывод
            edit_data
            ;;
        2)
            if [ -z "$IP_HQ" ] || [ -z "$IP_BR" ]; then
                echo "IP addresses not set. Please set them in option 1 first."
                read -p "Press Enter to continue..."
                continue
            fi
            apt-get update
            apt-get install -y mc wget nftables ipcalc
            for iface in $INTERFACE_HQ $INTERFACE_BR; do
                mkdir -p /etc/net/ifaces/$iface
                echo -e "BOOTPROTO=static\nTYPE=eth\nDISABLED=no\nCONFIG_IPV4=yes" > /etc/net/ifaces/$iface/options
                if [ "$iface" = "$INTERFACE_HQ" ]; then
                    echo $IP_HQ > /etc/net/ifaces/$iface/ipv4address
                elif [ "$iface" = "$INTERFACE_BR" ]; then
                    echo $IP_BR > /etc/net/ifaces/$iface/ipv4address
                fi
            done
            systemctl restart network
            ;;
        3)
            if [ -z "$IP_HQ" ] || [ -z "$IP_BR" ]; then
                echo "IP addresses not set. Please set them in option 1 first."
                read -p "Press Enter to continue..."
                continue
            fi
            sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
            sysctl -p
            systemctl enable --now nftables
            nft flush ruleset
            nft add table ip nat
            nft add chain ip nat postrouting '{ type nat hook postrouting priority 0; }'
            HQ_PREFIX=$(echo $IP_HQ | cut -d'/' -f2)
            BR_PREFIX=$(echo $IP_BR | cut -d'/' -f2)
            HQ_NETWORK=$(get_network $IP_HQ)
            BR_NETWORK=$(get_network $IP_BR)
            if [ -z "$HQ_NETWORK" ] || [ -z "$BR_NETWORK" ]; then
                echo "Error calculating network addresses. Please check your IP inputs."
                read -p "Press Enter to continue..."
                continue
            fi
            nft add rule ip nat postrouting ip saddr $HQ_NETWORK/$HQ_PREFIX oifname "ens192" counter masquerade
            nft add rule ip nat postrouting ip saddr $BR_NETWORK/$BR_PREFIX oifname "ens192" counter masquerade
            nft list ruleset > /etc/nftables/nftables.nft
            systemctl restart nftables
            ;;
        4)
            if [ -z "$HOSTNAME" ]; then
                echo "Hostname not set. Please set it in option 1 first."
                read -p "Press Enter to continue..."
                continue
            fi
            echo $HOSTNAME > /etc/hostname
            hostnamectl set-hostname $HOSTNAME
            echo "Hostname set to $HOSTNAME."
            read -p "Press Enter to continue..."
            ;;
        5)
            while true; do
                clear
                echo "Configuration Status:"
                echo "Hostname ---> $(check_config "hostname")"
                echo "Interfaces (except ens192) ---> $(check_config "interfaces")"
                echo "nftables ---> $(check_config "nftables")"
                echo "Time Zone ---> $(check_config "time_zone")"
                echo "0. Back to menu"
                read -p "Enter your choice: " sub_choice
                if [ "$sub_choice" = "0" ]; then
                    break
                else
                    echo "Invalid choice. Press 0 to go back."
                    read -p "Press Enter to continue..."
                fi
            done
            ;;
        6)
            while true; do
                clear
                echo "Remove Configurations Menu"
                echo "1. Remove interface configurations"
                echo "2. Remove nftables configurations"
                echo "3. Remove time zone configuration"
                echo "4. Remove hostname configuration"
                echo "5. Remove all configurations"
                echo "6. Remove everything done by this script"
                echo "0. Back to main menu"
                read -p "Enter your choice: " remove_choice
                case $remove_choice in
                    1)
                        remove_config "interfaces"
                        ;;
                    2)
                        remove_config "nftables"
                        ;;
                    3)
                        remove_config "time_zone"
                        ;;
                    4)
                        remove_config "hostname"
                        ;;
                    5)
                        remove_config "all"
                        ;;
                    6)
                        remove_config "all"
                        rm -f /etc/nftables/nftables.nft
                        rm -f /etc/nftables/nftables.nft.bak
                        rm -f /etc/nftables/nftables.nft.*
                        systemctl stop nftables
                        systemctl disable nftables
                        sed -i 's/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf
                        sysctl -p
                        echo "Everything done by this script has been removed."
                        ;;
                    0)
                        break
                        ;;
                    *)
                        echo "Invalid choice. Please try again."
                        read -p "Press Enter to continue..."
                        ;;
                esac
            done
            ;;
        7)
            show_help
            ;;
        0)
            clear
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
done
