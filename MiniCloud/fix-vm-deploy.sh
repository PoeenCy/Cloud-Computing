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

# 2. Xóa sạch TOÀN BỘ các container của MiniCloud (để tránh lỗi ContainerConfig của compose v1)
echo "--- Aggressively cleaning up all MiniCloud containers ---"
# Lấy danh sách ID các container có tên chứa 'minicloud-' và xóa chúng
MINICLOUD_CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep "minicloud-")

if [ -n "$MINICLOUD_CONTAINERS" ]; then
    echo "Containers found: $MINICLOUD_CONTAINERS"
    docker rm -f $MINICLOUD_CONTAINERS
    echo "All MiniCloud containers have been removed."
else
    echo "No MiniCloud containers found to remove."
fi

# 3. Dựng lại hệ thống bằng docker-compose.cloud.yml
echo "--- Deploying system on Port 80 ---"
# Đảm bảo dùng file cloud config
docker-compose -f docker-compose.cloud.yml up -d

# 4. Patch lỗi "HTTPS required" của Keycloak (do chạy trên Port 80 không có SSL)
echo "--- Patching Keycloak: Disabling SSL requirement ---"
echo "Waiting for database to be ready..."
RETRIES=10
until docker exec minicloud-db mariadb -uadmin -predis_secret_123 -e "SELECT 1" >/dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "  Waiting for MariaDB... ($RETRIES retries left)"
    sleep 5
    RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
    echo "Error: Database not ready, skipping patch."
else
    echo "MariaDB is ready. Applying patch..."
    # Update realm master để tắt yêu cầu SSL (ssl_required = 'NONE')
    docker exec minicloud-db mariadb -uadmin -predis_secret_123 -Dminicloud \
        -e "UPDATE REALM SET ssl_required = 'NONE' WHERE id = 'master';"
    echo "Patch applied! Keycloak will now allow HTTP access to the Admin Console."
fi

# 5. Kiểm tra trạng thái
echo "--- Current Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Done! Hãy kiểm tra lại các URL sau trên trình duyệt:"
echo "1. http://\${SERVER_IP}/auth/ (Keycloak Console)"
echo "2. http://\${SERVER_IP}/ (Trang chủ MiniCloud)"
