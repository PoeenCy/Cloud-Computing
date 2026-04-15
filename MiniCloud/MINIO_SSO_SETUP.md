# Hướng dẫn cấu hình MinIO SSO với Keycloak

## Tổng quan
MinIO hỗ trợ đăng nhập SSO (Single Sign-On) thông qua OpenID Connect (OIDC) với Keycloak. Sau khi cấu hình, người dùng có thể đăng nhập vào MinIO Console bằng tài khoản Keycloak mà không cần nhập lại username/password.

## Bước 1: Tạo Client trong Keycloak

### 1.1. Truy cập Keycloak Admin Console
```
URL: http://localhost:8088/auth/
Username: admin
Password: (xem trong MiniCloud/secrets/kc_admin_password.txt)
```

### 1.2. Chọn Realm
- Chọn realm: **realm_52300267** (dropdown góc trên bên trái)

### 1.3. Tạo Client mới
1. Vào menu **Clients** → Click **Create client**
2. Điền thông tin:
   - **Client type**: `OpenID Connect`
   - **Client ID**: `minio`
   - Click **Next**

3. **Capability config**:
   - ✅ **Client authentication**: ON (để lấy client secret)
   - ✅ **Authorization**: OFF
   - ✅ **Standard flow**: ON (Authorization Code Flow)
   - ✅ **Direct access grants**: OFF
   - ✅ **Implicit flow**: OFF
   - Click **Next**

4. **Login settings**:
   - **Root URL**: `http://localhost:8088`
   - **Home URL**: `http://localhost:8088/minio/`
   - **Valid redirect URIs**: 
     ```
     http://localhost:8088/minio/oauth_callback
     http://localhost:8088/minio/*
     ```
   - **Valid post logout redirect URIs**: `http://localhost:8088/minio/`
   - **Web origins**: `http://localhost:8088`
   - Click **Save**

### 1.4. Lấy Client Secret
1. Vào tab **Credentials** của client `minio`
2. Copy **Client secret** (ví dụ: `abc123xyz...`)
3. **QUAN TRỌNG**: Cập nhật secret vào `docker-compose.yml`:
   ```yaml
   MINIO_IDENTITY_OPENID_CLIENT_SECRET: "abc123xyz..."
   ```

### 1.5. Cấu hình Mappers (Optional nhưng khuyến nghị)
Để MinIO nhận đúng thông tin user từ Keycloak:

1. Vào tab **Client scopes** → Click vào `minio-dedicated`
2. Vào tab **Mappers** → Click **Add mapper** → **By configuration**
3. Chọn **User Property** và tạo mapper:
   - **Name**: `username`
   - **Property**: `username`
   - **Token Claim Name**: `preferred_username`
   - **Claim JSON Type**: `String`
   - ✅ **Add to ID token**: ON
   - ✅ **Add to access token**: ON
   - ✅ **Add to userinfo**: ON
   - Click **Save**

## Bước 2: Cập nhật Docker Compose

File `docker-compose.yml` đã được cấu hình sẵn với các biến môi trường OIDC:

```yaml
storage:
  environment:
    MINIO_BROWSER_REDIRECT_URL: "http://localhost:8088/minio/"
    MINIO_IDENTITY_OPENID_CONFIG_URL: "http://10.10.1.13:8080/auth/realms/realm_52300267/.well-known/openid-configuration"
    MINIO_IDENTITY_OPENID_CLIENT_ID: "minio"
    MINIO_IDENTITY_OPENID_CLIENT_SECRET: "minio-secret"  # ← Thay bằng secret thật từ Keycloak
    MINIO_IDENTITY_OPENID_SCOPES: "openid,profile,email"
    MINIO_IDENTITY_OPENID_REDIRECT_URI: "http://localhost:8088/minio/oauth_callback"
    MINIO_IDENTITY_OPENID_CLAIM_NAME: "preferred_username"
    MINIO_IDENTITY_OPENID_CLAIM_PREFIX: ""
```

**Lưu ý**: Thay `minio-secret` bằng Client Secret thật từ Keycloak (Bước 1.4)

## Bước 3: Khởi động lại MinIO

```bash
# Dừng và xóa container cũ
docker stop minicloud-storage
docker rm minicloud-storage

# Khởi động lại với cấu hình mới
docker compose up -d storage

# Kiểm tra logs
docker logs minicloud-storage -f
```

Hoặc khởi động lại toàn bộ hệ thống:
```bash
docker compose down
docker compose up -d
```

## Bước 4: Kiểm tra cấu hình

### 4.1. Kiểm tra OIDC endpoint
```bash
curl http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration
```

Kết quả phải trả về JSON với các endpoint như:
- `authorization_endpoint`
- `token_endpoint`
- `userinfo_endpoint`

### 4.2. Kiểm tra MinIO logs
```bash
docker logs minicloud-storage 2>&1 | grep -i oidc
```

Nếu thành công, sẽ thấy log:
```
API: SYSTEM()
API: SYSTEM() OpenID Connect is configured
```

## Bước 5: Test SSO Flow

### 5.1. Đăng nhập vào Website
1. Truy cập: http://localhost:8088/
2. Click **Đăng nhập**
3. Nhập credentials:
   - Username: `testuser`
   - Password: `Test@123`

### 5.2. Truy cập MinIO Console
1. Truy cập: http://localhost:8088/minio/
2. Bạn sẽ thấy 2 options:
   - **Login with SSO** ← Click vào đây
   - Login with credentials (root user)

3. Click **Login with SSO**
4. Nếu đã đăng nhập Keycloak → tự động redirect về MinIO Console
5. Nếu chưa đăng nhập → redirect đến Keycloak login page

### 5.3. Kiểm tra User trong MinIO
Sau khi đăng nhập SSO thành công:
- User sẽ được tạo tự động trong MinIO với username từ Keycloak
- Mặc định user SSO có quyền **read-only**
- Admin cần cấp policy/permissions cho user qua MinIO Console

## Bước 6: Cấp quyền cho User SSO (Optional)

### 6.1. Đăng nhập bằng Root User
1. Truy cập: http://localhost:8088/minio/
2. Chọn **Login with credentials**
3. Nhập:
   - Username: `admin` (từ `storage_root_user.txt`)
   - Password: `minio_admin_secret_123!` (từ `storage_root_pass.txt`)

### 6.2. Tạo Policy cho SSO Users
1. Vào menu **Identity** → **Policies**
2. Click **Create Policy**
3. Tạo policy với quyền phù hợp (ví dụ: readwrite)

### 6.3. Gán Policy cho User
1. Vào menu **Identity** → **Users**
2. Tìm user SSO (ví dụ: `testuser`)
3. Click vào user → Tab **Policies**
4. Assign policy đã tạo

## Troubleshooting

### Lỗi: "Login with SSO" button không hiện
**Nguyên nhân**: MinIO chưa nhận được cấu hình OIDC

**Giải pháp**:
```bash
# Kiểm tra env vars
docker exec minicloud-storage env | grep MINIO_IDENTITY

# Restart container
docker restart minicloud-storage
```

### Lỗi: "Invalid redirect_uri"
**Nguyên nhân**: Redirect URI trong Keycloak client không khớp

**Giải pháp**:
- Kiểm tra lại **Valid redirect URIs** trong Keycloak client `minio`
- Phải có: `http://localhost:8088/minio/oauth_callback`

### Lỗi: "Invalid client credentials"
**Nguyên nhân**: Client Secret sai

**Giải pháp**:
- Copy lại Client Secret từ Keycloak
- Cập nhật vào `docker-compose.yml`
- Restart MinIO container

### Lỗi: 504 Gateway Timeout
**Nguyên nhân**: Nginx không kết nối được MinIO

**Giải pháp**:
```bash
# Kiểm tra MinIO có chạy không
docker ps | grep storage

# Kiểm tra network
docker exec minicloud-proxy ping -c 2 10.10.2.15

# Reload nginx
docker exec minicloud-proxy nginx -s reload
```

### User SSO không có quyền gì
**Nguyên nhân**: MinIO mặc định không cấp quyền cho user SSO mới

**Giải pháp**:
- Đăng nhập bằng root user
- Gán policy cho user SSO (xem Bước 6)

## Tài liệu tham khảo

- [MinIO Identity Management - OpenID](https://min.io/docs/minio/linux/operations/external-iam/configure-openid-external-identity-management.html)
- [Keycloak OpenID Connect](https://www.keycloak.org/docs/latest/server_admin/#_oidc)
- [MinIO Console SSO](https://github.com/minio/console/blob/master/docs/oidc.md)

## Tóm tắt

✅ **Đã hoàn thành**:
- Cấu hình OIDC environment variables trong docker-compose.yml
- Cấu hình Nginx reverse proxy cho MinIO Console
- Hướng dẫn tạo Keycloak client

⏳ **Cần làm**:
1. Tạo client `minio` trong Keycloak realm `realm_52300267`
2. Copy Client Secret và cập nhật vào docker-compose.yml
3. Restart MinIO container
4. Test SSO flow

🎯 **Kết quả mong đợi**:
- User đăng nhập vào website → truy cập MinIO Console → tự động authenticated
- Không cần nhập lại username/password
- Quản lý user tập trung qua Keycloak
