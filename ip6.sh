#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}


install_3proxy() {
    echo "installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}


gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth none
proxy -6 -n -a -p3128 -i$IP4 -e$IP6
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

dow_proxy() {
    cd /home/proxy
    curl -F "file=@proxy.txt" https://transfer.sh
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "ip6tables -I INPUT -p tcp --dport " $2 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $3 "/64"}' ${WORKDATA})
EOF
}

check_live_proxy() {
    echo "Checking live proxies..."

    while IFS= read -r proxy_info; do
        IFS='/' read -ra proxy <<< "$proxy_info"
        ip="${proxy[0]}"
        port="${proxy[1]}"

        if curl -x "http://${ip}:${port}" --max-time 5 -s -o /dev/null; then
            echo "Proxy ${ip}:${port} is live."
        else
            echo "Proxy ${ip}:${port} is not responding."
        fi
    done < "$WORKDATA"
}

rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    new_ipv6=$(get_new_ipv6)
    update_3proxy_config "$new_ipv6"
    service 3proxy restart
    echo "3proxy restarted successfully."
    echo "IPv6 rotation completed."
}

get_new_ipv6() {
    random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
    echo "$random_ipv6"
}

update_3proxy_config() {
    new_ipv6=$1
    sed -i "s/old_ipv6_address/$new_ipv6/" /usr/local/etc/3proxy/3proxy.cfg
}

add_rotation_cronjob() {
    echo "*/10 * * * * root ${WORKDIR}/rotate_proxies.sh" >> /etc/crontab
    echo "Cronjob added for IPv6 rotation every 10 minutes."
}

menu() {
    clear
    echo "1. Check Live Proxies"
    echo "2. Rotate IPv6 Addresses"
    echo "3. Download Proxy List"
    echo "4. Exit"
    read -p "Enter your choice: " choice
    case $choice in
        1)
            check_live_proxy
            ;;
        2)
            rotate_ipv6
            ;;
        3)
            dow_proxy
            ;;
        4)
            echo "Exiting..."
            exit
            ;;
        *)
            echo "Invalid choice. Please enter a valid option."
            ;;
    esac
}

WORKDIR="/home/proxy"
WORKDATA="${WORKDIR}/data.txt"
DATA_FILE="${WORKDIR}/data.txt"

echo "installing apps"
yum -y install gcc net-tools bsdtar zip >/dev/null

echo "working folder = ${WORKDIR}"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for IPv6 = ${IP6}"

echo "How many proxies do you want to create? Example 10000"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$DATA_FILE
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF


bash /etc/rc.local

gen_proxy_file_for_user

dow_proxy

echo "Setting up rotation script..."

# Tạo script rotate_proxies.sh
echo '#!/bin/bash' > ${WORKDIR}/rotate_proxies.sh
echo 'new_ipv6=$(get_new_ipv6)' >> ${WORKDIR}/rotate_proxies.sh
echo 'update_3proxy_config "$new_ipv6"' >> ${WORKDIR}/rotate_proxies.sh
echo 'service 3proxy restart' >> ${WORKDIR}/rotate_proxies.sh
chmod +x ${WORKDIR}/rotate_proxies.sh

# Thêm vào crontab để xoay tự động
add_rotation_cronjob

echo "Setup Hoàn Tất."
