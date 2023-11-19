#!/bin/bash

echo "Script tạo hàng loạt card mạng ảo bridge vào eth0 trên CentOS 7"
echo "-------------------------------------------------------------"

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script này cần chạy với quyền root. Hãy sử dụng lệnh 'sudo'."
    exit 1
fi

# Cài đặt các gói cần thiết
echo "Cài đặt các gói cần thiết..."
yum install -y libvirt virt-install qemu-kvm

read -p "Nhập số lượng card mạng ảo muốn tạo: " num_networks

# Tạo card mạng bridge (br0)
echo "Tạo card mạng bridge (br0)"
br0_xml=$(cat <<EOF
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF
)
virsh net-define <(echo "$br0_xml")
virsh net-start br0
virsh net-autostart br0

# Tạo card mạng ảo
for ((i=1; i<=num_networks; i++))
do
    echo ""
    echo "Tạo card mạng ảo thứ $i"
    
    read -p "Nhập tên máy ảo: " vm_name
    mac_address=$(printf '52:54:00:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    
    vmnet_xml=$(cat <<EOF
<interface type="network">
  <mac address="$mac_address"/>
  <source network="br0"/>
  <model type="virtio"/>
  <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0"/>
</interface>
EOF
)

    vmnet_file="vmnet$i.xml"
    echo "$vmnet_xml" > "$vmnet_file"
    sed -i "s/52:54:00:01:01:01/$mac_address/g" "$vmnet_file"
    
    virsh attach-device "$vm_name" "$vmnet_file" --config
    
    echo "Đã tạo card mạng ảo $i thành công và gắn vào máy ảo $vm_name"
done

echo "Hoàn thành!"
