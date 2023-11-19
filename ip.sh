#!/bin/bash

CONFIG_FILE="/etc/app_config.conf"
PROXY_CONFIG_FILE="/etc/3proxy/3proxy.cfg"
LOG_FILE="/var/log/3proxy.log"

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0" "a" "b" "c" "d" "e" "f")

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6 || exit 1
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR || exit 1
}

download_proxy() {
    cd /home/cloudfly
    curl -F "file=@proxy.txt" https://transfer.sh
}

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

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

gen_data() {
    userproxy=$(random)
    passproxy=$(random)
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$userproxy/$passproxy/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

rotate_proxies() {
    while true; do
        sleep 600  # Sleep for 10 minutes
        echo "Rotating proxies..."
        gen_data >$WORKDIR/data.txt
        gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
        echo "Proxies rotated."
    done
}

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

show_proxy_list() {
    echo "Proxy List:"
    cat proxy.txt
}

display_menu() {
  clear
  echo "========== 3Proxy Management Menu =========="
  echo "[1] Enable IP Authentication"
  echo "[2] Disable IP Authentication"
  echo "[3] Generate New Ports"
  echo "[4] Enable Auto Rotate"
  echo "[5] Create and Download Proxies"
  echo "[6] Show Proxy List"
  echo "[7] Exit"
  echo "============================================"
}

menu_option() {
  read -p "Enter your choice [1-7]: " choice
  case $choice in
    1) enable_ip_authentication ;;
    2) disable_ip_authentication ;;
    3) generate_new_ports ;;
    4) enable_auto_rotate ;;
    5) create_and_download_proxies ;;
    6) show_proxy_list ;;
    7) exit ;;
    *) echo "Invalid option. Please choose again." ;;
  esac
}

apply_configuration_changes() {
  # This is a placeholder function.
  # In a real implementation, you might reload or apply your specific configurations here.
  echo "Applying configuration changes..."
  # Example: systemctl restart your_service
  sleep 2
}

enable_ip_authentication() {
  echo "Enabling IP Authentication..."

  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/IP_AUTHENTICATION=false/IP_AUTHENTICATION=true/' "$CONFIG_FILE"
    apply_configuration_changes
  else
    echo "Error: Configuration file not found."
  fi

  echo "IP Authentication enabled successfully."
  sleep 2
}

disable_ip_authentication() {
  echo "Disabling IP Authentication..."

  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/IP_AUTHENTICATION=true/IP_AUTHENTICATION=false/' "$CONFIG_FILE"
    apply_configuration_changes
  else
    echo "Error: Configuration file not found."
  fi

  echo "IP Authentication disabled successfully."
  sleep 2
}

generate_new_ports() {
  echo "Generating New Ports..."

  starting_port=60000
  number_of_ports=5

  for ((i = 0; i < number_of_ports; i++)); do
    new_port=$((starting_port + i))
    echo "New Port: $new_port"
    # Your logic to use the new port as needed
  done

  echo "New Ports generated successfully."
  sleep 2
}

enable_auto_rotate() {
  echo "Enabling Auto Rotate..."

  auto_rotate=true

  while [ "$auto_rotate" = true ]; do
    rotate_proxies
    sleep 600  # Sleep for 10 minutes
  done

  echo "Auto Rotate disabled."
}

create_and_download_proxies() {
  echo "Creating and Downloading Proxies..."

  gen_data > "$PROXY_CONFIG_FILE"
  download_proxy
  echo "Proxies created and downloaded successfully."
  sleep 2
}

download_proxy() {
  # Your logic for downloading proxies
  # Example: curl -F "file=@$PROXY_CONFIG_FILE" https://transfer.sh
  echo "Downloading proxies..."
}

show_proxy_list() {
  echo "Proxy List:"
  # Your logic to display the proxy list
  # Example: cat proxy.txt
}

rotate_proxies() {
  echo "Rotating proxies..."
  new_ipv6=$(get_new_ipv6)
  update_3proxy_config "$new_ipv6"
  restart_3proxy
  echo "Proxies rotated successfully."
}

get_new_ipv6() {
  random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
  echo "$random_ipv6"
}

update_3proxy_config() {
  new_ipv6=$1
  sed -i "s/old_ipv6_address/$new_ipv6/" "$PROXY_CONFIG_FILE"
}

restart_3proxy() {
  # Your logic to restart the 3proxy service
  systemctl restart 3proxy.service
}

echo "Installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

install_3proxy

# Set your allowed private IP addresses here
ALLOWED_IPS=("113.176.102.183" "115.75.249.144")

echo "allow ${ALLOWED_IPS[@]}" >> /usr/local/etc/3proxy/3proxy.cfg

echo "Working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External sub for IPv6 = ${IP6}"

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

LAST_PORT=$(($FIRST_PORT + 5000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 1000048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Start the proxy rotation and restart in the background
rotate_and_restart &

chmod 0755 /etc/rc.local

# Main menu loop
while true; do
  display_menu
  menu_option
done
