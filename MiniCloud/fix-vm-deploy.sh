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
echo "--- Aggressively cleaning up all MiniCloud containers and volumes ---"
# Lấy danh sách ID các container có tên chứa 'minicloud-' và xóa chúng
MINICLOUD_CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep "minicloud-")

if [ -n "$MINICLOUD_CONTAINERS" ]; then
    echo "Containers found: $MINICLOUD_CONTAINERS"
    docker rm -f $MINICLOUD_CONTAINERS
    echo "All MiniCloud containers have been removed."
else
    echo "No MiniCloud containers found to remove."
fi

# Xóa volume DB để reset mật khẩu (Người dùng đã đồng ý)
echo "Wiping database volume for a clean start..."
docker volume rm minicloud_db_data 2>/dev/null || echo "Volume not found or busy, skipping."

# 3. Tạo Chứng chỉ SSL tự động (Self-Signed) cho HTTPS
echo "--- Ensuring SSL Certificate exists ---"
if [ ! -d "./nginx/ssl" ]; then
    mkdir -p ./nginx/ssl
fi

# Luôn cập nhật thông tin IP mới nhất nếu có thể
IP_SUBJECT=$(hostname -I | awk '{print $1}')
echo "Generating/Updating self-signed SSL certificate for IP: $IP_SUBJECT"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ./nginx/ssl/nginx.key \
    -out ./nginx/ssl/nginx.crt \
    -subj "/C=VN/ST=HCM/L=HCM/O=MiniCloud/CN=$IP_SUBJECT"
echo "SSL Certificate updated!"

# 4. Dựng lại hệ thống bằng docker-compose.cloud.yml
echo "--- Deploying system over HTTPS (Port 443) ---"
# Đọc các mật khẩu từ file secrets
if [ -f "./secrets/db_password.txt" ]; then
    export DB_PASSWORD=$(cat ./secrets/db_password.txt | tr -d '\n\r')
fi

if [ -f "./secrets/kc_admin_password.txt" ]; then
    export KEYCLOAK_ADMIN_PASSWORD=$(cat ./secrets/kc_admin_password.txt | tr -d '\n\r')
fi

# Tự động lấy SERVER_IP nếu chưa được set trong .env
export SERVER_IP=${SERVER_IP:-$IP_SUBJECT}
echo "Deploying with SERVER_IP: $SERVER_IP"

# Đảm bảo dùng file cloud config
docker-compose -f docker-compose.cloud.yml up -d

# 5. Kiểm tra trạng thái
echo "--- Current Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Done! Hãy kiểm tra lại các URL sau trên trình duyệt:"
echo "1. http://\${SERVER_IP}/auth/ (Keycloak Console)"
echo "2. http://\${SERVER_IP}/ (Trang chủ MiniCloud)"
