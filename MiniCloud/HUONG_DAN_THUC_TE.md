# 🎯 Hướng dẫn thực tế - Setup MinIO SSO

## ❗ Vấn đề hiện tại

Bạn đang gặp 2 vấn đề:
1. ❌ MinIO không có button "Login with SSO"
2. ❓ Không biết truy cập Keycloak Admin Console

**Nguyên nhân**: Container MinIO đang chạy với cấu hình CŨ (trước khi tôi thêm OIDC vào docker-compose.yml)

---

## 🔍 Bước 1: Truy cập Keycloak Admin Console

### Cách 1: Qua Browser (Dễ nhất)

1. Mở browser, truy cập: **http://localhost:8088/auth/**

2. Bạn sẽ thấy trang Keycloak:
   ```
   Welcome to Keycloak
   
   [Administration Console]  [Account Console]
   ```

3. Click vào **"Administration Console"**

4. Đăng nhập:
   - **Username**: `admin`
   - **Password**: Xem trong file `MiniCloud/secrets/kc_admin_password.txt`

### Cách 2: Lấy password từ file

```bash
cd MiniCloud
cat secrets/kc_admin_password.txt
```

Password là: `keycloak_admin_super_secret_123!`

### Sau khi đăng nhập

Bạn sẽ thấy Keycloak Admin Console với:
- Sidebar bên trái: Clients, Users, Groups, Roles, etc.
- Dropdown góc trên trái: Chọn realm (hiện tại là `master`)

---

## 🔧 Bước 2: Restart MinIO với cấu hình mới

Container MinIO hiện tại đang chạy với cấu hình CŨ. Cần restart để áp dụng cấu hình OIDC mới:

```bash
cd MiniCloud

# Dừng và xóa container cũ
docker compose stop storage
docker compose rm -f storage

# Khởi động lại với cấu hình mới
docker compose up -d storage

# Đợi 10 giây để MinIO khởi động
Start-Sleep -Seconds 10

# Kiểm tra logs
docker logs minicloud-storage
```

### Kiểm tra OIDC đã được load chưa

```bash
docker exec minicloud-storage env | Select-String "MINIO_IDENTITY"
```

Nếu thành công, bạn sẽ thấy:
```
MINIO_IDENTITY_OPENID_CONFIG_URL=http://10.10.1.13:8080/auth/realms/realm_52300267/.well-known/openid-configuration
MINIO_IDENTITY_OPENID_CLIENT_ID=minio
MINIO_IDENTITY_OPENID_CLIENT_SECRET=minio-secret
...
```

---

## 🎯 Bước 3: Tạo Keycloak Client

### 3.1. Chọn Realm đúng

1. Trong Keycloak Admin Console
2. Click dropdown góc trên trái (hiện đang là `master`)
3. Chọn: **`realm_52300267`**

### 3.2. Tạo Client mới

1. Sidebar bên trái → Click **"Clients"**

2. Click button **"Create client"** (góc trên bên phải)

3. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `minio`
   - Name: `MinIO Console` (optional)
   - Click **Next**

4. **Capability config**:
   - ✅ **Client authentication**: ON (quan trọng!)
   - ✅ **Authorization**: OFF
   - ✅ **Standard flow**: ON
   - ✅ **Direct access grants**: OFF
   - ✅ **Implicit flow**: OFF
   - Click **Next**

5. **Login settings**:
   - Root URL: `http://localhost:8088`
   - Home URL: `http://localhost:8088/minio/`
   - Valid redirect URIs: `http://localhost:8088/minio/*`
   - Valid post logout redirect URIs: `http://localhost:8088/minio/`
   - Web origins: `http://localhost:8088`
   - Click **Save**

### 3.3. Lấy Client Secret

1. Sau khi Save, bạn sẽ thấy tabs: Settings, Credentials, Roles, etc.

2. Click tab **"Credentials"**

3. Bạn sẽ thấy:
   ```
   Client Authenticator: Client Id and Secret
   
   Client secret: [abc123xyz456...]  [Regenerate] [Copy]
   ```

4. Click button **"Copy"** để copy Client Secret

5. **LƯU LẠI** secret này, ví dụ: `abc123xyz456...`

---

## 🔄 Bước 4: Cập nhật Client Secret vào Docker Compose

### 4.1. Mở file docker-compose.yml

**KHÔNG CẦN** sửa `docker-compose.yml` nữa! Hệ thống đã dùng Docker Secrets.

### 4.2. Tạo secret file

Thay vì hardcode vào docker-compose.yml, tạo file secret:

```bash
cd MiniCloud/secrets
echo -n "abc123xyz456..." > minio_oidc_client_secret.txt
```

**Lưu ý**: 
- Dùng `echo -n` để không thêm newline
- Thay `abc123xyz456...` bằng Client Secret thật từ Keycloak
- File này đã nằm trong `.gitignore`, không bị commit lên Git

### 4.3. Kiểm tra file đã tạo đúng chưa

```bash
cat minio_oidc_client_secret.txt
# Phải hiển thị đúng Client Secret, không có khoảng trắng hay newline thừa
```

---

## 🚀 Bước 5: Restart MinIO lần nữa

```bash
cd MiniCloud

# Restart với secret mới
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage

# Đợi MinIO khởi động
Start-Sleep -Seconds 10
```

---

## ✅ Bước 6: Kiểm tra kết quả

### 6.1. Kiểm tra logs

```bash
docker logs minicloud-storage 2>&1 | Select-String "OpenID"
```

Nếu thành công, sẽ thấy:
```
API: SYSTEM() OpenID Connect is configured
```

### 6.2. Truy cập MinIO Console

1. Mở browser: **http://localhost:8088/minio/**

2. Bạn sẽ thấy trang login với **2 options**:
   ```
   ┌─────────────────────────────┐
   │   MinIO Console Login       │
   ├─────────────────────────────┤
   │                             │
   │  [Login with SSO]  ← CÓ NÀY!│
   │                             │
   │  ─────── OR ────────        │
   │                             │
   │  Username: [________]       │
   │  Password: [________]       │
   │  [Login]                    │
   └─────────────────────────────┘
   ```

3. Click **"Login with SSO"**

4. Nếu chưa đăng nhập Keycloak → redirect đến trang login Keycloak

5. Đăng nhập:
   - Username: `testuser`
   - Password: `Test@123`

6. Sau khi đăng nhập → tự động redirect về MinIO Console Dashboard

---

## 🎓 Test User trong Keycloak

Nếu chưa có user `testuser`, tạo mới:

### Tạo User trong Keycloak

1. Keycloak Admin Console → Realm: `realm_52300267`

2. Sidebar → **Users** → Click **"Add user"**

3. Điền thông tin:
   - Username: `testuser`
   - Email: `test@example.com`
   - First name: `Test`
   - Last name: `User`
   - ✅ Email verified: ON
   - Click **Create**

4. Sau khi tạo → Tab **"Credentials"**

5. Click **"Set password"**:
   - Password: `Test@123`
   - Password confirmation: `Test@123`
   - ❌ Temporary: OFF (để không phải đổi password lần đầu)
   - Click **Save**

6. Tab **"Role mapping"** → Assign roles nếu cần

---

## 🔍 Troubleshooting

### Vấn đề 1: Không thấy button "Login with SSO"

**Kiểm tra**:
```bash
docker exec minicloud-storage env | Select-String "MINIO_IDENTITY"
```

Nếu không có output → MinIO chưa nhận được cấu hình OIDC

**Giải pháp**:
```bash
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage
```

### Vấn đề 2: Click "Login with SSO" bị lỗi "Invalid redirect_uri"

**Nguyên nhân**: Valid redirect URIs trong Keycloak client không đúng

**Giải pháp**:
1. Keycloak Admin → Clients → `minio` → Settings
2. Valid redirect URIs: `http://localhost:8088/minio/*`
3. Save

### Vấn đề 3: "Invalid client credentials"

**Nguyên nhân**: Client Secret sai

**Giải pháp**:
1. Keycloak → Clients → `minio` → Credentials → Copy secret
2. Cập nhật vào `docker-compose.yml`
3. Restart MinIO

### Vấn đề 4: Không truy cập được Keycloak Admin

**Kiểm tra container**:
```bash
docker ps | Select-String "auth"
```

Nếu không chạy:
```bash
docker compose up -d auth
```

**Kiểm tra URL**:
- ✅ Đúng: `http://localhost:8088/auth/`
- ❌ Sai: `http://localhost:8088/auth` (thiếu dấu `/` cuối)

---

## 📋 Checklist tổng hợp

- [ ] Truy cập được Keycloak Admin: http://localhost:8088/auth/
- [ ] Đăng nhập Keycloak với admin credentials
- [ ] Chọn realm: `realm_52300267`
- [ ] Tạo client `minio` với Client authentication ON
- [ ] Copy Client Secret từ tab Credentials
- [ ] Cập nhật Client Secret vào `docker-compose.yml`
- [ ] Restart MinIO container
- [ ] Kiểm tra logs: `docker logs minicloud-storage`
- [ ] Truy cập MinIO: http://localhost:8088/minio/
- [ ] Thấy button "Login with SSO"
- [ ] Click "Login with SSO" và test

---

## 🎯 Kết quả mong đợi

Sau khi hoàn thành tất cả bước:

1. ✅ Truy cập http://localhost:8088/minio/
2. ✅ Thấy button **"Login with SSO"**
3. ✅ Click button → redirect đến Keycloak
4. ✅ Đăng nhập Keycloak → redirect về MinIO Dashboard
5. ✅ Không cần nhập lại username/password

---

## 💡 Lưu ý quan trọng

1. **Client Secret phải giữ bí mật** - Đừng commit vào Git
2. **Realm phải đúng** - `realm_52300267`, không phải `master`
3. **Client authentication phải ON** - Nếu không sẽ không có Client Secret
4. **Valid redirect URIs phải có** - `http://localhost:8088/minio/*`
5. **Container phải restart** - Sau khi thay đổi docker-compose.yml

---

**Thời gian thực hiện**: 10-15 phút  
**Độ khó**: ⭐⭐☆☆☆  

Nếu gặp vấn đề, hãy cho tôi biết bạn đang ở bước nào! 🚀
