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
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

rotate_script="${WORKDIR}/rotate_proxies.sh"
echo '#!/bin/bash' > "$rotate_script"
echo 'new_ipv6=$(get_new_ipv6)' >> "$rotate_script"
echo 'update_3proxy_config "$new_ipv6"' >> "$rotate_script"
echo 'restart_3proxy' >> "$rotate_script"
chmod +x "$rotate_script"

# Add rotation to crontab for automatic rotation

add_rotation_cronjob() {
    echo "*/10 * * * * $rotate_script" >> /etc/crontab
}

command -v wget >/dev/null 2>&1 || { echo >&2 "wget is required but not installed. Aborting."; exit 1; }
command -v gcc >/dev/null 2>&1 || { echo >&2 "gcc is required but not installed. Aborting."; exit 1; }
command -v bsdtar >/dev/null 2>&1 || { echo >&2 "bsdtar is required but not installed. Aborting."; exit 1; }


WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir "$WORKDIR" && cd "$_"

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IPv6 subnet = ${IP6}"

while :; do
    read -p "Enter FIRST_PORT from 10000 to 60000: " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number is outside the range, please try again"
    fi
done

LAST_PORT=$(($FIRST_PORT + 2000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg


gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 1000048
service 3proxy start
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
chmod 0755 /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user

echo "Starting Proxy"
download_proxy
