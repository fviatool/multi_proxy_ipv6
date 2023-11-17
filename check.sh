check_current_ports_and_proxies() {
  echo "Checking Current Ports and Proxies..."

  # Lấy danh sách các cổng mở
  open_ports=($(netstat -tuln | awk '$4 ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/ {split($4, a, ":"); print a[2]}'))

  # Kiểm tra số lượng cổng đang sử dụng
  total_ports=$(netstat -tuln | grep -cE ':[0-9]+ ')

  # Thay thế 'your_proxy_command' bằng lệnh thực tế bạn sử dụng để kiểm tra trạng thái proxy
  proxy_status=$(your_actual_proxy_command)

  echo "Total Ports: $total_ports"
  echo "Proxy Status: $proxy_status"

  # Hiển thị danh sách các cổng mở
  echo "Open Ports:"
  for port in "${open_ports[@]}"; do
    echo "$port"
  done

  echo "Check completed."
}
