# 🔧 MiniCloud GCP Fix Guide

## 🚨 Tình huống hiện tại
- Máy GCP đang chạy nhưng **Keycloak auth không hoạt động**
- Hệ thống chạy **chậm và lag**
- Chỉ có **web service** hoạt động bình thường

## 🎯 Mục tiêu
Sửa lỗi và khôi phục toàn bộ hệ thống MiniCloud trên GCP

---

## 🚀 Cách sử dụng (Đơn giản nhất)

### Bước 1: Chạy script fix tự động
```bash
# Từ thư mục gốc project (nơi có folder MiniCloud)
chmod +x run-fix.sh
./run-fix.sh
```

### Bước 2: Chọn option trong menu
```
=== MiniCloud Fix Options ===
1. 🔍 Quick system check        <- Bắt đầu với cái này
2. 🔧 Full system debug & fix   <- Nếu option 1 thấy lỗi
3. 🔐 Fix Keycloak specifically <- Nếu chỉ Keycloak lỗi
4. 🖥️  VM management            <- Start/Stop/Restart VM
5. 📊 View system status        <- Xem trạng thái containers
6. 🌐 Test website access       <- Test các URL
7. 📋 View logs                 <- Xem logs lỗi
8. 🆘 Emergency full restart    <- Restart toàn bộ hệ thống
```

---

## 🔍 Chẩn đoán nhanh

### Kiểm tra VM có chạy không
```bash
gcloud compute instances list
```

### Nếu VM bị tắt
```bash
gcloud compute instances start minicloud-demo --zone=asia-southeast1-a
```

### SSH vào VM để kiểm tra
```bash
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

Trong VM:
```bash
cd ~/MiniCloud
docker ps                    # Xem containers nào đang chạy
docker compose ps           # Xem trạng thái chi tiết
docker logs minicloud-auth  # Xem lỗi Keycloak
```

---

## 🔐 Fix Keycloak (Lỗi phổ biến nhất)

### Nguyên nhân thường gặp:
1. **Database connection failed** - MariaDB chưa sẵn sàng
2. **Memory issues** - VM không đủ RAM
3. **Network issues** - Container không kết nối được
4. **Configuration errors** - Sai cấu hình hostname/URL

### Fix nhanh Keycloak:
```bash
# SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Trong VM:
cd ~/MiniCloud

# Restart Keycloak
docker compose restart minicloud-auth

# Hoặc rebuild Keycloak
docker compose stop minicloud-auth
docker compose rm -f minicloud-auth
docker compose up -d minicloud-auth

# Xem logs
docker logs -f minicloud-auth
```

### Kiểm tra Keycloak health:
```bash
# Trong VM
curl http://localhost/auth/health/ready
curl http://localhost/auth/admin/
```

---

## 🗄️ Fix Database Issues

### Kiểm tra database:
```bash
# Trong VM
docker logs minicloud-db
docker exec minicloud-db mysql -u admin -p$(cat secrets/db_password.txt) -e "SELECT 1;"
```

### Restart database:
```bash
docker compose restart minicloud-db
sleep 15  # Đợi database khởi động
docker compose restart minicloud-auth  # Restart Keycloak sau database
```

---

## 🌐 Fix Network Issues

### Kiểm tra networks:
```bash
docker network ls
docker network inspect minicloud_frontend-net
```

### Recreate networks:
```bash
docker compose down
docker network prune -f
docker compose up -d
```

---

## 📊 Monitoring & Logs

### Xem tất cả logs:
```bash
docker compose logs -f
```

### Xem logs từng service:
```bash
docker logs -f minicloud-auth      # Keycloak
docker logs -f minicloud-db        # Database
docker logs -f minicloud-proxy     # Nginx
docker logs -f minicloud-app       # Flask API
```

### Kiểm tra resource usage:
```bash
docker stats
free -h
df -h
```

---

## 🆘 Emergency Procedures

### 1. Full System Restart
```bash
# Trong VM
cd ~/MiniCloud
docker compose down
docker system prune -f
docker compose up -d
```

### 2. VM Restart (từ local)
```bash
gcloud compute instances reset minicloud-demo --zone=asia-southeast1-a
```

### 3. Rebuild từ đầu
```bash
# Trong VM
cd ~/MiniCloud
docker compose down -v  # Xóa cả volumes
docker system prune -a -f
docker compose up -d --build
```

---

## ✅ Verification Checklist

Sau khi fix, kiểm tra các URL này:

- [ ] **Website**: `http://VM_IP/`
- [ ] **API**: `http://VM_IP/api/hello`
- [ ] **Keycloak Admin**: `http://VM_IP/auth/admin/`
- [ ] **Grafana**: `http://VM_IP/grafana/`
- [ ] **Prometheus**: `http://VM_IP/prometheus/`

### Credentials mặc định:
- **Keycloak**: admin / KcAdmin@2024!
- **Grafana**: admin / admin

---

## 🔧 Manual Fix Commands

### Nếu script tự động không hoạt động:

```bash
# 1. SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# 2. Vào thư mục MiniCloud
cd ~/MiniCloud

# 3. Kiểm tra .env file
cat .env
# Nếu không có, tạo:
echo "SERVER_IP=$(curl -s ifconfig.me)" > .env
echo "DB_NAME=minicloud" >> .env
echo "DB_USER=admin" >> .env
echo "REDIS_PASSWORD=redis_secret_123" >> .env

# 4. Kiểm tra secrets
ls -la secrets/
# Nếu thiếu, tạo:
mkdir -p secrets
echo "RootPass@2024!" > secrets/db_root_password.txt
echo "DbPass@2024!" > secrets/db_password.txt
echo "KcAdmin@2024!" > secrets/kc_admin_password.txt
echo "minioadmin" > secrets/storage_root_user.txt
echo "MinioPass@2024!" > secrets/storage_root_pass.txt

# 5. Restart services theo thứ tự
docker compose stop
docker compose up -d minicloud-dns
sleep 10
docker compose up -d minicloud-db minicloud-redis
sleep 20
docker compose up -d minicloud-auth
sleep 30
docker compose up -d
```

---

## 📞 Troubleshooting

### Lỗi: "gcloud: command not found"
```bash
# Cài Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

### Lỗi: "Permission denied (publickey)"
```bash
gcloud compute config-ssh
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

### Lỗi: VM không start được
```bash
# Kiểm tra quota
gcloud compute project-info describe

# Enable APIs
gcloud services enable compute.googleapis.com
```

### Lỗi: Website không truy cập được
```bash
# Kiểm tra firewall
gcloud compute firewall-rules list

# Tạo lại firewall rule
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server
```

---

## 💡 Tips

1. **Luôn kiểm tra VM status trước**: `gcloud compute instances list`
2. **Keycloak cần 2-3 phút để start hoàn toàn**
3. **Database phải start trước Keycloak**
4. **Nếu hết RAM, restart VM**: `gcloud compute instances reset minicloud-demo --zone=asia-southeast1-a`
5. **Backup trước khi fix**: `docker compose down` (không dùng `-v`)

---

## 🎯 Quick Commands Reference

```bash
# VM Management
gcloud compute instances list
gcloud compute instances start minicloud-demo --zone=asia-southeast1-a
gcloud compute instances stop minicloud-demo --zone=asia-southeast1-a
gcloud compute instances reset minicloud-demo --zone=asia-southeast1-a

# SSH
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Docker (trong VM)
docker ps
docker compose ps
docker compose restart minicloud-auth
docker logs -f minicloud-auth

# Network test
curl http://localhost/
curl http://localhost/api/hello
curl http://localhost/auth/admin/
```

---

**🎉 Chúc bạn fix thành công!**

Nếu vẫn gặp vấn đề, hãy chạy `./run-fix.sh` và chọn option 2 (Full system debug) để có thông tin chi tiết hơn.