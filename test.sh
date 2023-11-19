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
        echo "//$IP4/$port/$(gen64 $IP6)"
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
WORKDATA="${WORKDIR}/data.txt"
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
LAST_PORT=$(($FIRST_PORT + 1500))
echo "LAST_PORT is $LAST_PORT. Continue..."

gen_data >$WORKDIR/data.txt
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

CONFIG_FILE="/etc/app_config.conf"
PROXY_CONFIG_FILE="/etc/3proxy/3proxy.cfg"
LOG_FILE="/var/log/3proxy.log"

display_menu() {
  clear
  echo "========== Menu Quản lý 3Proxy =========="
  echo "[1] Bật xác thực IP"
  echo "[2] Tắt xác thực IP"
  echo "[3] Tạo cổng mới"
  echo "[4] Bật xoay tự động"
  echo "[5] Tạo và Tải Proxy"
  echo "[6] Hiển thị danh sách Proxy"
  echo "[7] Tải về danh sách Proxy"
  echo "[8] Thoát"
  echo "=========================================="
}

menu_option() {
  read -p "Nhập lựa chọn của bạn [1-8]: " choice
  case $choice in
    1) enable_ip_authentication ;;
    2) disable_ip_authentication ;;
    3) generate_new_ports ;;
    4) enable_auto_rotate ;;
    5) create_and_download_proxies ;;
    6) show_proxy_list ;;
    7) download_proxy_list ;;
    8) exit ;;
    *) echo "Lựa chọn không hợp lệ. Vui lòng chọn lại." ;;
  esac
}

apply_configuration_changes() {
  # Đây là một hàm giữ chỗ.
  # Trong một triển khai thực tế, bạn có thể tải lại hoặc áp dụng cấu hình cụ thể của bạn ở đây.
  echo "Áp dụng các thay đổi cấu hình..."
  # Ví dụ: systemctl restart your_service
  sleep 2
}

enable_ip_authentication() {
  echo "Bật xác thực IP..."

  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/IP_AUTHENTICATION=false/IP_AUTHENTICATION=true/' "$CONFIG_FILE"
    apply_configuration_changes
  else
    echo "Lỗi: Không tìm thấy tệp cấu hình."
  fi

  echo "Bật xác thực IP thành công."
  sleep 2
}

disable_ip_authentication() {
  echo "Tắt xác thực IP..."

  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/IP_AUTHENTICATION=true/IP_AUTHENTICATION=false/' "$CONFIG_FILE"
    apply_configuration_changes
  else
    echo "Lỗi: Không tìm thấy tệp cấu hình."
  fi

  echo "Tắt xác thực IP thành công."
  sleep 2
}

generate_new_ports() {
  echo "Tạo Cổng Mới..."

  starting_port=50000
  number_of_ports=1500

  for ((i = 0; i < number_of_ports; i++)); do
    new_port=$((starting_port + i))
    echo "Cổng Mới: $new_port"
    # Logic của bạn để sử dụng cổng mới khi cần
  done

  echo "Tạo cổng mới thành công."
  sleep 2
}

enable_auto_rotate() {
  echo "Bật Xoay Tự Động..."

  auto_rotate=true

  while [ "$auto_rotate" = true ]; do
    rotate_proxies
    sleep 600  # Ngủ 10 phút
  done

  echo "Tắt Xoay Tự Động."
}

create_and_download_proxies() {
  echo "Tạo và Tải Proxy..."

  gen_data > "$PROXY_CONFIG_FILE"
  download_proxy
  echo "Proxy đã được tạo và tải thành công."
  sleep 2
}

download_proxy() {
  echo "Downloading proxies..."
  curl -F "$PROXY_CONFIG_FILE" https://transfer.sh > proxy.txt
  echo "Proxies downloaded successfully."
}

show_proxy_list() {
  echo "Proxy List:"
  cat "$PROXY_CONFIG_FILE"
}

download_proxy_list() {
  echo "Tải về danh sách Proxy..."
  curl -F "$PROXY_CONFIG_FILE" https://transfer.sh > proxy.txt
  echo "Đã tải về danh sách Proxy."
}

rotate_proxies() {
  echo "Xoay Proxy..."
  new_ipv6=$(get_new_ipv6)
  update_3proxy_config "$new_ipv6"
  restart_3proxy
  echo "Proxy đã được xoay thành công."
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
  # Logic của bạn để khởi động lại dịch vụ 3proxy
  systemctl restart 3proxy.service
}

# Vòng lặp menu chính
while true; do
  display_menu
  menu_option
done
