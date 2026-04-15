#!/bin/bash
# Script hỗ trợ cấu hình MinIO SSO với Keycloak

set -e

echo "=================================================="
echo "  MinIO SSO Setup Helper"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Kiểm tra containers đang chạy
echo -e "${BLUE}[1/6] Kiểm tra containers...${NC}"
if ! docker ps | grep -q minicloud-auth; then
    echo -e "${RED}❌ Keycloak container chưa chạy!${NC}"
    echo "Chạy: docker compose up -d"
    exit 1
fi

if ! docker ps | grep -q minicloud-storage; then
    echo -e "${RED}❌ MinIO container chưa chạy!${NC}"
    echo "Chạy: docker compose up -d"
    exit 1
fi

echo -e "${GREEN}✅ Containers đang chạy${NC}"
echo ""

# Kiểm tra OIDC endpoint
echo -e "${BLUE}[2/6] Kiểm tra Keycloak OIDC endpoint...${NC}"
OIDC_URL="http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration"
if curl -sf "$OIDC_URL" > /dev/null; then
    echo -e "${GREEN}✅ OIDC endpoint hoạt động${NC}"
else
    echo -e "${RED}❌ Không thể kết nối OIDC endpoint${NC}"
    echo "URL: $OIDC_URL"
    exit 1
fi
echo ""

# Hướng dẫn tạo Keycloak client
echo -e "${BLUE}[3/6] Tạo Keycloak Client${NC}"
echo -e "${YELLOW}Bạn cần tạo client 'minio' trong Keycloak:${NC}"
echo ""
echo "1. Truy cập: http://localhost:8088/auth/"
echo "2. Đăng nhập với admin credentials"
echo "3. Chọn realm: realm_52300267"
echo "4. Vào Clients → Create client"
echo "5. Điền thông tin:"
echo "   - Client ID: minio"
echo "   - Client authentication: ON"
echo "   - Standard flow: ON"
echo "   - Valid redirect URIs: http://localhost:8088/minio/oauth_callback"
echo ""
read -p "Đã tạo client 'minio' chưa? (y/n): " created_client

if [[ ! "$created_client" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Vui lòng tạo client trước khi tiếp tục${NC}"
    echo "Xem hướng dẫn chi tiết: MiniCloud/MINIO_SSO_SETUP.md"
    exit 0
fi
echo ""

# Nhập Client Secret
echo -e "${BLUE}[4/6] Cập nhật Client Secret${NC}"
echo "Lấy Client Secret từ Keycloak:"
echo "  Clients → minio → Credentials tab → Copy Client Secret"
echo ""
read -p "Nhập Client Secret: " client_secret

if [ -z "$client_secret" ]; then
    echo -e "${RED}❌ Client Secret không được để trống${NC}"
    exit 1
fi

# Cập nhật docker-compose.yml
echo -e "${YELLOW}Đang cập nhật docker-compose.yml...${NC}"
sed -i.bak "s/MINIO_IDENTITY_OPENID_CLIENT_SECRET: \".*\"/MINIO_IDENTITY_OPENID_CLIENT_SECRET: \"$client_secret\"/" docker-compose.yml
echo -e "${GREEN}✅ Đã cập nhật Client Secret${NC}"
echo ""

# Restart MinIO
echo -e "${BLUE}[5/6] Khởi động lại MinIO container...${NC}"
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage

echo -e "${YELLOW}Đợi MinIO khởi động (10s)...${NC}"
sleep 10

# Kiểm tra MinIO logs
echo -e "${BLUE}[6/6] Kiểm tra MinIO logs...${NC}"
if docker logs minicloud-storage 2>&1 | grep -qi "OpenID Connect is configured"; then
    echo -e "${GREEN}✅ MinIO đã cấu hình OIDC thành công!${NC}"
else
    echo -e "${YELLOW}⚠️  Không tìm thấy log OIDC, kiểm tra thủ công:${NC}"
    echo "docker logs minicloud-storage 2>&1 | grep -i oidc"
fi
echo ""

# Kết quả
echo "=================================================="
echo -e "${GREEN}✅ Hoàn tất cấu hình!${NC}"
echo "=================================================="
echo ""
echo "Bước tiếp theo:"
echo "1. Truy cập: http://localhost:8088/minio/"
echo "2. Click 'Login with SSO'"
echo "3. Đăng nhập bằng Keycloak (testuser / Test@123)"
echo ""
echo "Nếu gặp lỗi, xem hướng dẫn troubleshooting:"
echo "  MiniCloud/MINIO_SSO_SETUP.md"
echo ""
