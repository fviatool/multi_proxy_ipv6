#!/bin/bash

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
    echo "installing 3proxy..."
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

users \$(awk -F "/" 'BEGIN{ORS="";} {print \$1 ":CL:" \$2 " "}' \${WORKDATA})

\$(awk -F "/" '{print "auth strong\n" \
"allow " \$1 "\n" \
"proxy -6 -n -a -p" \$4 " -i" \$3 " -e"\$5"\n" \
"flush\n"}' \${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    awk -F "/" '{print \$3 ":" \$4 ":" \$1 ":" \$2 }' \${WORKDATA} > proxy.txt
}

gen_data() {
    userproxy=\$(random)
    passproxy=\$(random)
    seq \$FIRST_PORT \$LAST_PORT | while read port; do
        echo "\$userproxy/\$passproxy/\$IP4/\$port/\$(gen64 \$IP6)"
    done
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " \$4 "  -m state --state NEW -j ACCEPT"}' \${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " \$5 "/64"}' \${WORKDATA}
}

rotate_proxies() {
    while true; do
        echo "Rotating proxies..."
        gen_data >\$WORKDIR/data.txt
        gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
        sleep 10
    done
}

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="\${WORKDIR}/data.txt"
mkdir \$WORKDIR && cd \$_

IP4=\$(curl -4 -s icanhazip.com)
IP6=\$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = \${IP4}. External sub for IPv6 = \${IP6}"

while :; do
  read -p "Enter FIRST_PORT between 10000 and 60000: " FIRST_PORT
  [[ \$FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
    echo "OK! Valid number"
    break
  else
    echo "Number out of range, try again"
  fi
done

LAST_PORT=\$(\$FIRST_PORT + 10000)
echo "LAST_PORT is \$LAST_PORT. Continue..."

gen_data >\$WORKDIR/data.txt
gen_iptables >\$WORKDIR/boot_iptables.sh
gen_ifconfig >\$WORKDIR/boot_ifconfig.sh
chmod +x "\${WORKDIR}"/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash \${WORKDIR}/boot_iptables.sh
bash \${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user

echo "Starting Proxy"

enable_auto_rotate

show_menu() {
    clear
    echo "Menu:"
    echo "1. Tạo proxy và tải về"
    echo "2. Xoay proxy"
    echo "3. Hiển thị danh sách proxy"
    echo "4. Tải về danh sách proxy"
    echo "5. Thoát"
}

while true; do
    show_menu
    read -p "Chọn một tùy chọn (1-5): " choice

    case \$choice in
        1)
            gen_data >\$WORKDIR/data.txt
            gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
            echo "Proxy được tạo và thêm vào danh sách."
            ;;
        2)
            rotate_proxies &
            echo "Đã bắt đầu xoay proxy."
            ;;
        3)
            cat proxy.txt
            ;;
        4)
            download_proxy
            ;;
        5)
            echo "Thoát..."
            exit 0
            ;;
        *)
            echo "Tùy chọn không hợp lệ. Vui lòng chọn từ 1 đến 5."
            ;;
    esac

    sleep 2
done
