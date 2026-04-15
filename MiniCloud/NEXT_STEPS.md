# 🎯 Các bước tiếp theo - MinIO SSO Setup

## ✅ Đã hoàn thành

### 1. Cấu hình Docker Compose
- ✅ Thêm OIDC environment variables cho MinIO
- ✅ Sửa OIDC config URL (realm: `realm_52300267`)
- ✅ Cấu hình redirect URI: `http://localhost:8088/minio/oauth_callback`
- ✅ Proxy đã được thêm vào backend-net để kết nối MinIO

### 2. Cấu hình Nginx
- ✅ Thêm `proxy_intercept_errors off` để MinIO tự xử lý auth
- ✅ Thêm WebSocket support cho MinIO Console
- ✅ Sửa `proxy_redirect` để rewrite URLs đúng
- ✅ Proxy pass đến backend IP: `10.10.2.15:9001`

### 3. Documentation
- ✅ **MINIO_SSO_SETUP.md** - Hướng dẫn chi tiết từng bước
- ✅ **QUICK_START_SSO.md** - Quick start 5 phút
- ✅ **SSO_FLOW_DIAGRAM.md** - Sequence diagrams và flow charts
- ✅ **setup-minio-sso.sh** - Script tự động hóa
- ✅ **CHANGELOG.md** - Cập nhật lịch sử thay đổi

### 4. Git Repository
- ✅ Tất cả thay đổi đã được commit
- ✅ Đã push lên GitHub: https://github.com/PoeenCy/Cloud-Computing.git
- ✅ Branch: `main`

---

## ⏳ Cần làm tiếp (Bạn thực hiện)

### Bước 1: Tạo Keycloak Client (5 phút)

1. **Truy cập Keycloak Admin Console**:
   ```
   URL: http://localhost:8088/auth/
   Username: admin
   Password: (xem trong MiniCloud/secrets/kc_admin_password.txt)
   ```

2. **Chọn Realm**: `realm_52300267`

3. **Tạo Client**:
   - Menu: **Clients** → **Create client**
   - Client ID: `minio`
   - Client type: `OpenID Connect`
   - Client authentication: **ON**
   - Standard flow: **ON**
   - Valid redirect URIs: `http://localhost:8088/minio/oauth_callback`
   - Click **Save**

4. **Lấy Client Secret**:
   - Tab **Credentials**
   - Copy **Client secret**

### Bước 2: Cập nhật Client Secret (1 phút)

Mở file `MiniCloud/docker-compose.yml`, tìm dòng:

```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "minio-secret"
```

Thay bằng Client Secret thật từ Keycloak.

### Bước 3: Restart MinIO (2 phút)

```bash
cd MiniCloud
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage
```

Hoặc:
```bash
docker compose restart storage
```

### Bước 4: Kiểm tra Logs (1 phút)

```bash
docker logs minicloud-storage 2>&1 | grep -i oidc
```

Nếu thành công, sẽ thấy:
```
API: SYSTEM() OpenID Connect is configured
```

### Bước 5: Test SSO (2 phút)

1. Đăng nhập vào website: http://localhost:8088/
   - Username: `testuser`
   - Password: `Test@123`

2. Truy cập MinIO Console: http://localhost:8088/minio/

3. Click **"Login with SSO"**

4. Kiểm tra:
   - ✅ Tự động redirect về MinIO Dashboard
   - ✅ Không cần nhập lại username/password
   - ✅ User hiển thị trong MinIO Console

---

## 📚 Tài liệu tham khảo

### Quick Reference
- **5-minute setup**: `MiniCloud/QUICK_START_SSO.md`
- **Detailed guide**: `MiniCloud/MINIO_SSO_SETUP.md`
- **Flow diagrams**: `MiniCloud/SSO_FLOW_DIAGRAM.md`

### Automated Setup
```bash
cd MiniCloud
chmod +x setup-minio-sso.sh
./setup-minio-sso.sh
```

### Manual Commands
```bash
# Kiểm tra OIDC endpoint
curl http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration

# Kiểm tra MinIO env vars
docker exec minicloud-storage env | grep MINIO_IDENTITY

# Restart MinIO
docker restart minicloud-storage

# Xem logs
docker logs minicloud-storage -f

# Reload nginx
docker exec minicloud-proxy nginx -s reload
```

---

## 🔧 Troubleshooting

### "Login with SSO" button không hiện
**Nguyên nhân**: MinIO chưa nhận được cấu hình OIDC

**Giải pháp**:
```bash
docker exec minicloud-storage env | grep MINIO_IDENTITY
docker restart minicloud-storage
```

### "Invalid redirect_uri"
**Nguyên nhân**: Redirect URI trong Keycloak không khớp

**Giải pháp**:
- Kiểm tra **Valid redirect URIs** trong Keycloak client
- Phải có: `http://localhost:8088/minio/oauth_callback`

### "Invalid client credentials"
**Nguyên nhân**: Client Secret sai

**Giải pháp**:
- Copy lại Client Secret từ Keycloak
- Cập nhật vào `docker-compose.yml`
- Restart MinIO

### 504 Gateway Timeout
**Nguyên nhân**: Nginx không kết nối được MinIO

**Giải pháp**:
```bash
docker ps | grep storage
docker exec minicloud-proxy ping -c 2 10.10.2.15
docker exec minicloud-proxy nginx -s reload
```

---

## 🎓 Kiến thức bổ sung

### Cấp quyền cho User SSO

Mặc định user SSO chỉ có quyền **read-only**. Để cấp quyền:

1. Đăng nhập MinIO bằng root user:
   - Username: `admin`
   - Password: `minio_admin_secret_123!`

2. Vào **Identity** → **Users** → Tìm user SSO

3. Assign policy (ví dụ: `readwrite`, `consoleAdmin`)

### Tạo Policy tùy chỉnh

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

### Keycloak Role Mapping

Để map Keycloak roles sang MinIO policies:

1. Tạo Keycloak role: `minio-admin`
2. Assign role cho user
3. Cấu hình MinIO policy mapping (advanced)

---

## 📊 Checklist hoàn thành

- [ ] Tạo Keycloak client `minio`
- [ ] Copy Client Secret
- [ ] Cập nhật `docker-compose.yml`
- [ ] Restart MinIO container
- [ ] Kiểm tra logs (OIDC configured)
- [ ] Test SSO flow
- [ ] Cấp quyền cho user SSO (optional)

---

## 🚀 Sau khi hoàn thành

### Hệ thống sẽ có:
✅ 17 containers running  
✅ 3-tier network segmentation  
✅ High Availability (2 Web + 2 API instances)  
✅ Centralized authentication (Keycloak)  
✅ SSO cho MinIO Console  
✅ Monitoring (Prometheus + Grafana)  
✅ Log aggregation (Loki + Promtail)  
✅ CI/CD pipeline (GitHub Actions)  

### Services accessible:
- Website: http://localhost:8088/
- API: http://localhost:8088/api/hello
- Keycloak: http://localhost:8088/auth/
- Grafana: http://localhost:8088/grafana/
- Prometheus: http://localhost:8088/prometheus/
- MinIO Console: http://localhost:8088/minio/ (with SSO!)

---

## 💡 Tips

### Backup trước khi thay đổi
```bash
cp docker-compose.yml docker-compose.yml.backup
```

### Xem tất cả containers
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Xem logs realtime
```bash
docker compose logs -f storage
```

### Restart toàn bộ hệ thống
```bash
docker compose down
docker compose up -d
```

---

## 📞 Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `docker logs minicloud-storage`
2. Xem troubleshooting: `MiniCloud/MINIO_SSO_SETUP.md`
3. Kiểm tra network: `docker network inspect minicloud_backend-net`
4. Verify Keycloak: `curl http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration`

---

**Thời gian ước tính**: 10-15 phút  
**Độ khó**: ⭐⭐☆☆☆ (Dễ)  
**Status**: ⏳ Chờ bạn thực hiện Keycloak client setup  

**Good luck! 🚀**
