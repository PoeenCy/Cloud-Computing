#!/bin/bash

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

# 5. Tắt bắt buộc SSL trong Keycloak (fix lỗi 400 Bad Request)
echo "--- Waiting for Keycloak to be ready before disabling SSL requirement ---"
# Lấy linh động ID container của Keycloak
KC_CONTAINER=$(docker ps -qf "name=authentication-identity-server")
MAX_WAIT=120
WAITED=0

if [ -z "$KC_CONTAINER" ]; then
    echo "ERROR: Could not find Keycloak container! Waiting a bit and retrying..."
    sleep 10
    KC_CONTAINER=$(docker ps -qf "name=authentication-identity-server")
fi

if [ -n "$KC_CONTAINER" ]; then
    until docker exec "$KC_CONTAINER" /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user admin \
        --password admin 2>/dev/null; do
        if [ "$WAITED" -ge "$MAX_WAIT" ]; then
            echo "WARNING: Keycloak did not become ready in time. SSL may still be required."
            break
        fi
        echo "Keycloak not ready yet, waiting 5s... ($WAITED/${MAX_WAIT}s)"
        sleep 5
        WAITED=$((WAITED + 5))
    done

    echo "Disabling SSL requirement for realm: master"
    docker exec "$KC_CONTAINER" /opt/keycloak/bin/kcadm.sh update realms/master \
        -s sslRequired=none && echo "✓ master realm: sslRequired=none" || echo "✗ Failed to update master realm"

    echo "Disabling SSL requirement for realm: realm_52300267"
    docker exec "$KC_CONTAINER" /opt/keycloak/bin/kcadm.sh update realms/realm_52300267 \
        -s sslRequired=none && echo "✓ realm_52300267: sslRequired=none" || echo "✗ Failed to update realm_52300267"
else
    echo "✗ ERROR: Keycloak container still not found. Cannot disable SSL."
fi

# 6. Kiểm tra trạng thái
echo "--- Current Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Done! Hãy kiểm tra lại các URL sau trên trình duyệt:"
echo "1. http://\${SERVER_IP}/auth/ (Keycloak Console)"
echo "2. http://\${SERVER_IP}/ (Trang chủ MiniCloud)"
