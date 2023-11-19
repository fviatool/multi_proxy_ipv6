#!/bin/bash

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Function to generate a random IPv6 address
gen64() {
    ip64() {
        array=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0" "a" "b" "c" "d" "e" "f")
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to install 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
    echo "3proxy installed successfully."
}

# Function to generate 3proxy configuration
gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Function to generate proxy file for user
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

# Function to generate data
gen_data() {
    userproxy=$(random)
    passproxy=$(random)
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$userproxy/$passproxy/$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

# Function to generate ifconfig commands
gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

# Function to rotate proxies
rotate_proxies() {
    while true; do
        sleep 600  # Sleep for 10 minutes
        echo "Rotating proxies..."
        gen_data >$WORKDIR/data.txt
        gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
        echo "Proxies rotated."
    done
}

# Function to rotate and restart proxies
rotate_and_restart() {
    while true; do
        for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
            IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
            /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
            /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
        done
        sleep 900  # Sleep for 15 minutes (900 seconds)
    done
}

# Function to show proxy list
show_proxy_list() {
    echo "Proxy List:"
    cat proxy.txt
}

# Function to create proxy and download
create_proxy() {
    gen_data >$WORKDIR/data.txt
    gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
    gen_proxy_file_for_user
}

# Function to download proxy list
download_proxy() {
    cd $WORKDIR
    curl -F "file=@proxy.txt" https://transfer.sh
}

# Main menu
menu() {
    clear
    echo "Menu:"
    echo "1. Create proxy and download"
    echo "2. Rotate proxies"
    echo "3. Show proxy list"
    echo "4. Download proxy list"
    echo "5. Exit"
}

# Main part of the script
echo "Installing apps..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Create the initial working folder and set the configuration
cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

# Install 3proxy
install_3proxy

# Set your allowed private IP addresses here
ALLOWED_IPS=("113.176.102.183" "115.75.249.144")

# Add allowed IPs to 3proxy configuration
echo "allow ${ALLOWED_IPS[@]}" >> /usr/local/etc/3proxy/3proxy.cfg

# Set working folder and data file paths
echo "Working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

# Get external and internal IP addresses
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External sub for IPv6 = ${IP6}"

# Get the first port from the user
while :; do
    read -p "Enter FIRST_PORT between 10000 and 60000: " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number out of range, try again"
    fi
done

# Set the last port and display a message
LAST_PORT=$(($FIRST_PORT + 10000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

# Generate initial data, iptables rules, ifconfig commands, and 3proxy configuration
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Append commands to /etc/rc.local for initial setup
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 1000048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Start the proxy rotation and restart in the background
rotate_and_restart &

# Set permissions for /etc/rc.local
chmod 0755 /etc/rc.local

# Main menu loop
while true; do
    menu
    read -p "Choose an option (1-5): " choice

    case $choice in
        1)
            create_proxy
            echo "Proxy created and added to the list."
            download_proxy ;;
        2)
            rotate_proxies ;;
        3)
            show_proxy_list ;;
        4)
            download_proxy ;;
        5)
            echo "Exiting..."
            exit 0 ;;
        *)
            echo "Invalid option. Please choose from 1 to 5." ;;
    esac

    read -p "Press Enter to continue..."
done
