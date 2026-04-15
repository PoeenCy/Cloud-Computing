# MiniCloud - Cloud Deployment Guide

## 🌟 Phiên bản Cloud-Ready

Đây là phiên bản MiniCloud được tối ưu hóa cho triển khai trên cloud (GCP, AWS, Azure).

### ✨ Thay đổi so với phiên bản local:

1. **Port mapping**: `80:80` thay vì `8088:80` (chuẩn HTTP)
2. **Nginx config**: Sử dụng IP cố định thay vì hostname để tránh DNS issues
3. **Redis healthcheck**: Sử dụng shell TCP test thay vì wget
4. **Auto deployment script**: `deploy-cloud-final.sh`

### 🚀 Triển khai nhanh

```bash
# 1. Clone và checkout nhánh cloud
git clone <repository>
cd MiniCloud
git checkout cloud-deployment

# 2. Chạy script tự động
chmod +x deploy-cloud-final.sh
./deploy-cloud-final.sh

# 3. Kiểm tra
docker-compose ps
curl http://localhost/
```

### 🔧 Cấu hình thủ công

Nếu muốn tùy chỉnh:

```bash
# 1. Tạo secrets
mkdir -p secrets
echo "your_db_password" > secrets/db_password.txt
echo "your_root_password" > secrets/db_root_password.txt
echo "your_keycloak_password" > secrets/kc_admin_password.txt
echo "minioadmin" > secrets/storage_root_user.txt
echo "your_minio_password" > secrets/storage_root_pass.txt

# 2. Dừng systemd-resolved (Ubuntu/Debian)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 3. Khởi động
docker-compose up -d --build

# 4. Đợi containers khởi động
sleep 60
docker-compose ps
```

### 🌐 Truy cập

Sau khi triển khai thành công:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Website** | `http://YOUR_IP/` | - |
| **Keycloak Admin** | `http://YOUR_IP/auth/admin/` | `admin` / `keycloak_admin_super_secret_123!` |
| **Grafana** | `http://YOUR_IP/grafana/` | `admin` / `admin` |
| **Prometheus** | `http://YOUR_IP/prometheus/` | Cần đăng nhập website trước |
| **MinIO Console** | `http://YOUR_IP/minio/` | Cần đăng nhập website trước |

### 🔐 Bảo mật

**Quan trọng**: Đổi mật khẩu mặc định trước khi sử dụng production!

```bash
# Tạo mật khẩu ngẫu nhiên
openssl rand -base64 32 > secrets/db_password.txt
openssl rand -base64 32 > secrets/db_root_password.txt
openssl rand -base64 32 > secrets/kc_admin_password.txt
openssl rand -base64 32 > secrets/storage_root_pass.txt
```

### 🐛 Troubleshooting

**Container không start:**
```bash
docker-compose logs <container_name>
```

**Port 53 conflict:**
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

**Nginx config error:**
```bash
docker run --rm -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t
```

**Reset toàn bộ:**
```bash
docker-compose down -v
docker system prune -f
./deploy-cloud-final.sh
```

### 📊 Monitoring

Tất cả 17 containers phải có trạng thái **Up (healthy)**:

```bash
docker-compose ps --format "table {{.Names}}\t{{.Status}}"
```

### 🏗️ Kiến trúc

- **Frontend Network** (10.10.1.0/24): Proxy, Web, App, Auth
- **Backend Network** (10.10.2.0/24): DB, MinIO, Redis (isolated)  
- **Management Network** (10.10.3.0/24): DNS, Prometheus, Grafana, Loki

### 📝 Logs

```bash
# Xem logs tất cả containers
docker-compose logs -f

# Xem logs container cụ thể
docker-compose logs -f <service_name>

# Xem logs qua Grafana
# Truy cập http://YOUR_IP/grafana/ → Explore → Loki
```

---

**Phiên bản**: Cloud-Ready v1.0  
**Cập nhật**: April 2026  
**Tương thích**: Docker 20+, Docker Compose 2+