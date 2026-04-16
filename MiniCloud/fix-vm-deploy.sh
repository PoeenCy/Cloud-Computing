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

# 3. Tạo Chứng chỉ SSL tự động (Self-Signed) cho HTTPS
echo "--- Ensuring SSL Certificate exists ---"
if [ ! -d "./nginx/ssl" ]; then
    mkdir -p ./nginx/ssl
fi

if [ ! -f "./nginx/ssl/nginx.crt" ]; then
    echo "Generating self-signed SSL certificate for HTTPS..."
    # Lấy IP Public hoặc dùng localhost nếu không cấu hình SERVER_IP
    IP_SUBJECT=${SERVER_IP:-localhost}
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ./nginx/ssl/nginx.key \
        -out ./nginx/ssl/nginx.crt \
        -subj "/C=VN/ST=HCM/L=HCM/O=MiniCloud/CN=$IP_SUBJECT"
    echo "SSL Certificate generated!"
else
    echo "SSL Certificate already exists at ./nginx/ssl/nginx.crt"
fi

# 4. Dựng lại hệ thống bằng docker-compose.cloud.yml
echo "--- Deploying system over HTTPS (Port 443) ---"
# Đọc mật khẩu admin từ file để không bị lộ trong log hoặc file YAML
if [ -f "./secrets/kc_admin_password.txt" ]; then
    export KEYCLOAK_ADMIN_PASSWORD=$(cat ./secrets/kc_admin_password.txt)
else
    echo "Warning: secrets/kc_admin_password.txt not found. Using default 'admin'."
    export KEYCLOAK_ADMIN_PASSWORD="admin"
fi

# Đảm bảo dùng file cloud config
docker-compose -f docker-compose.cloud.yml up -d

# 5. Kiểm tra trạng thái
echo "--- Current Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Done! Hãy kiểm tra lại các URL sau trên trình duyệt:"
echo "1. http://\${SERVER_IP}/auth/ (Keycloak Console)"
echo "2. http://\${SERVER_IP}/ (Trang chủ MiniCloud)"
