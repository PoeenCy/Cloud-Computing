#!/bash

# 1. Sửa lỗi /etc/hosts để sudo không báo lỗi "unable to resolve host"
echo "--- Fixing /etc/hosts ---"
HOSTNAME=$(hostname)
if ! grep -q "$HOSTNAME" /etc/hosts; then
    echo "127.0.0.1 $HOSTNAME" | sudo tee -a /etc/hosts
    echo "Fixed /etc/hosts for hostname: $HOSTNAME"
else
    echo "/etc/hosts already contains $HOSTNAME"
fi

# 2. Xóa các container bị kẹt (lỗi KeyError: 'ContainerConfig' của docker-compose v1)
echo "--- Cleaning up problematic containers ---"
containers=("minicloud-proxy" "minicloud-auth" "minicloud-web1" "minicloud-web2" "minicloud-app" "minicloud-app2")

for container in "${containers[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
        echo "Removing $container..."
        docker rm -f "$container"
    fi
done

# 3. Dựng lại hệ thống bằng docker-compose.cloud.yml
echo "--- Deploying system on Port 80 ---"
# Đảm bảo dùng file cloud config
docker-compose -f docker-compose.cloud.yml up -d

# 4. Kiểm tra trạng thái
echo "--- Current Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Done! Hãy kiểm tra lại các URL sau trên trình duyệt:"
echo "1. http://\${SERVER_IP}/auth/ (Keycloak Console)"
echo "2. http://\${SERVER_IP}/ (Trang chủ MiniCloud)"
