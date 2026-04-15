# 🚀 Quick Start: MinIO SSO với Keycloak

## Tóm tắt nhanh

MinIO SSO đã được cấu hình sẵn trong `docker-compose.yml`. Bạn chỉ cần:
1. Tạo Keycloak client
2. Cập nhật Client Secret
3. Restart MinIO
4. Test!

---

## ⚡ Các bước thực hiện (5 phút)

### Bước 1: Truy cập Keycloak Admin Console

```
URL: http://localhost:8088/auth/
Username: admin
Password: (xem trong MiniCloud/secrets/kc_admin_password.txt)
```

### Bước 2: Tạo Client `minio`

1. **Chọn Realm**: `realm_52300267` (dropdown góc trên trái)

2. **Create Client**:
   - Menu: **Clients** → **Create client**
   - Client type: `OpenID Connect`
   - Client ID: `minio`
   - Click **Next**

3. **Capability config**:
   - ✅ Client authentication: **ON**
   - ✅ Standard flow: **ON**
   - ❌ Direct access grants: OFF
   - Click **Next**

4. **Login settings**:
   ```
   Root URL: http://localhost:8088
   Valid redirect URIs: http://localhost:8088/minio/oauth_callback
   Web origins: http://localhost:8088
   ```
   - Click **Save**

5. **Lấy Client Secret**:
   - Tab **Credentials**
   - Copy **Client secret** (ví dụ: `abc123xyz...`)

### Bước 3: Cập nhật Client Secret

Mở file `MiniCloud/docker-compose.yml`, tìm dòng:

```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "minio-secret"
```

Thay `minio-secret` bằng Client Secret thật từ Keycloak:

```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "abc123xyz..."
```

### Bước 4: Restart MinIO

```bash
cd MiniCloud
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage
```

Hoặc restart toàn bộ:
```bash
docker compose restart
```

### Bước 5: Test SSO

1. **Đăng nhập vào website**:
   - URL: http://localhost:8088/
   - Click **Đăng nhập**
   - Username: `testuser`
   - Password: `Test@123`

2. **Truy cập MinIO Console**:
   - URL: http://localhost:8088/minio/
   - Bạn sẽ thấy 2 options:
     - **Login with SSO** ← Click vào đây
     - Login with credentials

3. **Click "Login with SSO"**:
   - Nếu đã đăng nhập Keycloak → tự động vào MinIO Console
   - Nếu chưa → redirect đến Keycloak login page

---

## ✅ Kiểm tra nhanh

### Kiểm tra OIDC endpoint
```bash
curl http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration
```

Phải trả về JSON với `authorization_endpoint`, `token_endpoint`, etc.

### Kiểm tra MinIO logs
```bash
docker logs minicloud-storage 2>&1 | grep -i oidc
```

Nếu thành công, sẽ thấy:
```
API: SYSTEM() OpenID Connect is configured
```

### Kiểm tra containers
```bash
docker ps | grep -E "storage|auth"
```

Cả 2 containers phải đang chạy (status: Up).

---

## 🔧 Troubleshooting nhanh

### "Login with SSO" button không hiện
```bash
# Kiểm tra env vars
docker exec minicloud-storage env | grep MINIO_IDENTITY

# Restart
docker restart minicloud-storage
```

### "Invalid redirect_uri"
- Kiểm tra lại **Valid redirect URIs** trong Keycloak
- Phải có: `http://localhost:8088/minio/oauth_callback`

### "Invalid client credentials"
- Client Secret sai
- Copy lại từ Keycloak → Cập nhật docker-compose.yml → Restart

### 504 Gateway Timeout
```bash
# Kiểm tra MinIO có chạy không
docker ps | grep storage

# Kiểm tra network
docker exec minicloud-proxy ping -c 2 10.10.2.15

# Reload nginx
docker exec minicloud-proxy nginx -s reload
```

---

## 📚 Tài liệu chi tiết

- **Hướng dẫn đầy đủ**: `MiniCloud/MINIO_SSO_SETUP.md`
- **Script tự động**: `MiniCloud/setup-minio-sso.sh`
- **Kiến trúc hệ thống**: `MiniCloud/ARCHITECTURE_SUMMARY.md`

---

## 🎯 Kết quả mong đợi

✅ User đăng nhập website → truy cập MinIO → tự động authenticated  
✅ Không cần nhập lại username/password  
✅ Quản lý user tập trung qua Keycloak  
✅ MinIO Console có button "Login with SSO"  

---

## 💡 Tips

### Cấp quyền cho User SSO
Mặc định user SSO chỉ có quyền read-only. Để cấp quyền:

1. Đăng nhập MinIO bằng root user:
   - Username: `admin`
   - Password: `minio_admin_secret_123!`

2. Vào **Identity** → **Users** → Tìm user SSO

3. Assign policy (ví dụ: `readwrite`, `consoleAdmin`)

### Tạo Policy tùy chỉnh
1. **Identity** → **Policies** → **Create Policy**
2. Định nghĩa permissions (JSON format)
3. Assign cho user/group

---

**Thời gian setup**: ~5 phút  
**Độ khó**: ⭐⭐☆☆☆ (Dễ)  
**Status**: ✅ Ready to use
