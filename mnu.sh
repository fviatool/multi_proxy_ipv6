#!/bin/bash

# Function to obtain the list of current IPv6 addresses
get_current_ipv6_list() {
    ipv6_list=($(ip -6 addr show | grep inet6 | awk '{print $2}'))
    echo "${ipv6_list[@]}"
}

# Function to generate a random IPv6 address
get_new_ipv6() {
    random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
    echo "$random_ipv6"
}

# Function to update 3proxy configuration with the new IPv6 address
update_3proxy_config() {
    local old_ipv6=$1
    local new_ipv6=$2
    sed -i "s/$old_ipv6/$new_ipv6/" /usr/local/etc/3proxy/3proxy.cfg
}

# Function to restart 3proxy
restart_3proxy() {
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sreload
}

# Function to add internal IP to the allow list
add_internal_ip() {
    read -p "Enter the internal IP address to add: " internal_ip
    # Validate the IP address before adding
    if [[ $internal_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        iptables -A INPUT -s $internal_ip -j ACCEPT
        service iptables save
        service iptables restart
        echo "Internal IP $internal_ip has been added to the allow list."
    else
        echo "Invalid IP address."
    fi
}

# Function to remove internal IP from the allow list
remove_internal_ip() {
    read -p "Enter the internal IP address to remove: " internal_ip
    iptables -D INPUT -s $internal_ip -j ACCEPT
    service iptables save
    service iptables restart
    echo "Internal IP $internal_ip has been removed from the allow list."
}

# Function to show the current allow list
show_allow_list() {
    echo "Current Allow List:"
    iptables -L INPUT -n --line-numbers | grep ACCEPT
    read -p "Press Enter to continue..."
}

# Function to enable the firewall
enable_firewall() {
    iptables -F
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p icmp -j ACCEPT
    iptables -A INPUT -j DROP
    iptables -A FORWARD -j DROP
    iptables -A OUTPUT -j ACCEPT
    service iptables save
    service iptables restart
    echo "Firewall has been enabled."
}

# Function to rotate all current IPv6 addresses without affecting IPv4
rotate_all_ipv6() {
    echo "Rotating all IPv6 addresses..."

    # Get the list of current IPv6 addresses
    current_ipv6_list=($(get_current_ipv6_list))

    # Rotate each IPv6 address
    for ipv6 in "${current_ipv6_list[@]}"; do
        # Generate new IPv6 address
        new_ipv6=$(get_new_ipv6)

        # Update 3proxy configuration with the new IPv6 address
        update_3proxy_config "$ipv6" "$new_ipv6"

        # Restart 3proxy to apply changes
        restart_3proxy

        echo "IPv6 rotation completed for: $ipv6"
    done

    echo "All IPv6 addresses rotated successfully."
}

# Function to manage IP addresses in the firewall
manage_ip_firewall() {
    echo "IP Address Management Menu:"
    echo "1. Add Internal IP to Allow List"
    echo "2. Remove Internal IP from Allow List"
    echo "3. Show Allow List"
    echo "4. Back to Main Menu"

    read -p "Enter your choice (1-4): " ip_choice

    case $ip_choice in
        1)
            add_internal_ip
            ;;
        2)
            remove_internal_ip
            ;;
        3)
            show_allow_list
            ;;
        4)
            return
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, or 4."
            ;;
    esac
}

# Main program
echo "IPv6 Rotation, Firewall, and IP Management Script"

while true; do
    clear  # Clear the screen
    echo "Main Menu:"
    echo "1. Rotate IPv6 Addresses"
    echo "2. Enable Firewall"
    echo "3. Manage IP Addresses"
    echo "4. Exit"

    read -p "Enter your choice (1-4): " choice

    case $choice in
        1)
            rotate_all_ipv6
            ;;
        2)
            enable_firewall
            ;;
        3)
            manage_ip_firewall
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, or 4."
            ;;
    esac

    sleep 2  # Wait for 2 seconds before displaying the menu again
done
