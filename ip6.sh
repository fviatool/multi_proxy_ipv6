#!/bin/sh

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

$(awk -F "/" '{print "allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP6/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
iptables -A INPUT -p tcp --dport 3128 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 1080 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -m state --state NEW -j ACCEPT
$(awk -F "/" '{print "iptables -A INPUT -p tcp --dport " $4 " -s " $3 " -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
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

WORKDIR="/home/proxy"
WORKDATA="${WORKDIR}/data.txt"
DATA_FILE="${WORKDIR}/data.txt"

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/proxy"
mkdir $WORKDIR && cd $_

IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "External sub for ip6 = ${IP6}"


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
service 3proxy start
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod 0755 /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

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

# Adjusted menu
show_menu() {
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

# Loop to display the menu
while true; do
    show_menu
done
