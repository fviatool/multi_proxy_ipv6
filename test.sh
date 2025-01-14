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
    #cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    #chmod +x /etc/init.d/3proxy
    #chkconfig 3proxy on
    cd $WORKDIR
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

$(awk -F "/" '{print "\n" \
"" $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP4:$port:$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/ipv6.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

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
LAST_PORT=$(($FIRST_PORT + 4444))
echo "LAST_PORT is $LAST_PORT. Continue..."

gen_data >$WORKDIR/ipv6.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"

#!/bin/bash

WORKDIR="/home/cloudfly"
IFCFG="eth0"
START_PORT=3001
MAXCOUNT=10000
IP_LIST_FILE="$WORKDIR/ipv6.txt"
LOG_FILE="$WORKDIR/proxy_list.txt"

rotate_ipv6() {
    if [ ! -f "$IP_LIST_FILE" ]; then
        echo "Error: Cannot find IPv6 list file ($IP_LIST_FILE)"
        return
    fi

    selected_ipv6=$(shuf -n 1 "$IP_LIST_FILE")

    if [ -z "$selected_ipv6" ]; then
        echo "Invalid selection. Please try again."
        return
    fi

    echo "Rotating IPv6: $selected_ipv6"
    update_3proxy_config "$selected_ipv6"
    service 3proxy restart
    echo "$(date) - Rotated IPv6: $selected_ipv6" >> "$LOG_FILE"
}

start_3proxy() {
    gen_3proxy_cfg > /usr/local/etc/3proxy/3proxy.cfg
    killall 3proxy
    service 3proxy start
    echo "$(date) - 3proxy has been started!" >> "$LOG_FILE"
}

gen_3proxy_cfg() {
    echo "daemon"
    echo "maxconn 3000"
    echo "nserver 1.1.1.1"
    echo "nserver 8.8.4.4"
    echo "nserver 2001:4860:4860::8888"
    echo "nserver 2001:4860:4860::8844"
    echo "nscache 65536"
    echo "timeouts 1 5 30 60 180 1800 15 60"
    echo "setgid 65535"
    echo "setuid 65535"
    echo "stacksize 6291456" 
    echo "flush"

    port=$START_PORT
    while read ip; do
        echo "proxy -6 -n -a -p$port -i$IFCFG -e$ip"
        ((port+=1))
    done < "$IP_LIST_FILE"
}

menu() {
    clear
    echo "===== IPv6 PROXY OPTIONS MENU ====="
    echo "1. Rotate IPv6"
    echo "2. Start IPv6 Proxy"
    echo "3. Display IPv6 Proxy List"
    echo "4. Exit"
    echo "==================================="
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Running the script requires root privileges."
        exit 1
    fi
}

while true; do
    menu
    read -p "Choose an option (1-4): " choice

    case $choice in
        1)
            check_root
            rotate_ipv6
            ;;
        2)
            check_root
            start_3proxy
            ;;
        3)
            echo "Displaying IPv6 Proxy List:"
            cat "$LOG_FILE"
            ;;
        4)
            echo "Exiting the program."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please choose again."
            ;;
    esac
done
