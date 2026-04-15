# 🚀 BẮT ĐẦU TỪ ĐÂY - MinIO SSO Setup

## ⚡ Tóm tắt siêu ngắn

Bạn cần làm 3 việc:
1. ✅ Truy cập Keycloak Admin và tạo client `minio`
2. ✅ Copy Client Secret vào `docker-compose.yml`
3. ✅ Restart MinIO container

**Thời gian**: 10 phút

---

## 📍 BƯỚC 1: Truy cập Keycloak Admin

### Mở browser và truy cập:
```
http://localhost:8088/auth/
```

### Bạn sẽ thấy trang này:

```
┌─────────────────────────────────────┐
│                                     │
│         Welcome to                  │
│         [Keycloak Logo]             │
│                                     │
│   [Administration Console]  ← CLICK │
│   [Account Console]                 │
│                                     │
└─────────────────────────────────────┘
```

### Click "Administration Console"

### Đăng nhập:
- **Username**: `admin`
- **Password**: `keycloak_admin_super_secret_123!`

(Hoặc xem trong file: `MiniCloud/secrets/kc_admin_password.txt`)

---

## 📍 BƯỚC 2: Chọn Realm đúng

Sau khi đăng nhập, bạn sẽ thấy:

```
┌─────────────────────────────────────┐
│ [master ▼]  Keycloak Admin Console │ ← Click dropdown này
├─────────────────────────────────────┤
│ Sidebar:                            │
│  - Realm settings                   │
│  - Clients                          │
│  - Users                            │
│  ...                                │
└─────────────────────────────────────┘
```

### Click dropdown "master" → Chọn: **`realm_52300267`**

---

## 📍 BƯỚC 3: Tạo Client

### 3.1. Click "Clients" trong sidebar bên trái

### 3.2. Click button "Create client" (góc trên phải)

### 3.3. Điền form:

**Tab 1: General Settings**
```
Client type: OpenID Connect
Client ID: minio
Name: MinIO Console (optional)
```
→ Click **Next**

**Tab 2: Capability config**
```
✅ Client authentication: ON  ← QUAN TRỌNG!
❌ Authorization: OFF
✅ Standard flow: ON
❌ Direct access grants: OFF
❌ Implicit flow: OFF
```
→ Click **Next**

**Tab 3: Login settings**
```
Root URL: http://localhost:8088
Home URL: http://localhost:8088/minio/
Valid redirect URIs: http://localhost:8088/minio/*
Web origins: http://localhost:8088
```
→ Click **Save**

---

## 📍 BƯỚC 4: Lấy Client Secret

Sau khi Save, bạn sẽ thấy tabs:

```
[Settings] [Credentials] [Roles] [Client scopes] ...
```

### Click tab "Credentials"

Bạn sẽ thấy:
```
Client Authenticator: Client Id and Secret

Client secret: abc123xyz456...  [Copy]
                                 ↑
                              CLICK ĐÂY
```

### Click button "Copy" để copy secret

### Paste vào Notepad để lưu tạm

---

## 📍 BƯỚC 5: Cập nhật docker-compose.yml

### 5.1. Mở file

```powershell
cd MiniCloud
notepad docker-compose.yml
```

### 5.2. Tìm dòng này (Ctrl+F tìm "MINIO_IDENTITY_OPENID_CLIENT_SECRET"):

```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "minio-secret"
```

### 5.3. Thay bằng Client Secret thật:

```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "abc123xyz456..."
```

**Lưu ý**: Giữ nguyên dấu ngoặc kép `""`

### 5.4. Save file (Ctrl+S)

---

## 📍 BƯỚC 6: Restart MinIO

### Cách 1: Dùng script PowerShell (Dễ nhất)

```powershell
cd MiniCloud
.\restart-minio.ps1
```

Script sẽ tự động:
- Dừng container cũ
- Xóa container cũ
- Khởi động lại với cấu hình mới
- Kiểm tra kết quả

### Cách 2: Chạy lệnh thủ công

```powershell
cd MiniCloud
docker compose stop storage
docker compose rm -f storage
docker compose up -d storage
```

Đợi 10 giây để MinIO khởi động.

---

## 📍 BƯỚC 7: Kiểm tra kết quả

### 7.1. Mở browser, truy cập:
```
http://localhost:8088/minio/
```

### 7.2. Bạn sẽ thấy trang login:

```
┌─────────────────────────────────┐
│   MinIO Console                 │
├─────────────────────────────────┤
│                                 │
│  [Login with SSO]  ← CÓ NÀY!   │
│                                 │
│  ─────── OR ────────            │
│                                 │
│  Username: [________]           │
│  Password: [________]           │
│  [Login]                        │
└─────────────────────────────────┘
```

### 7.3. Click "Login with SSO"

### 7.4. Đăng nhập Keycloak:
- Username: `testuser`
- Password: `Test@123`

### 7.5. Sau khi đăng nhập → Tự động vào MinIO Dashboard

---

## ❌ Nếu KHÔNG thấy button "Login with SSO"

### Kiểm tra 1: OIDC config đã load chưa?

```powershell
docker exec minicloud-storage env | Select-String "MINIO_IDENTITY"
```

**Nếu không có output** → MinIO chưa nhận được cấu hình

**Giải pháp**: Chạy lại script restart:
```powershell
.\restart-minio.ps1
```

### Kiểm tra 2: Client Secret đúng chưa?

Mở `docker-compose.yml`, tìm dòng:
```yaml
MINIO_IDENTITY_OPENID_CLIENT_SECRET: "..."
```

Đảm bảo secret không phải là `minio-secret` (đó là placeholder)

### Kiểm tra 3: Container có chạy không?

```powershell
docker ps | Select-String "storage"
```

Phải thấy: `minicloud-storage   Up ... (healthy)`

---

## 🆘 Troubleshooting nhanh

### Lỗi: "Invalid redirect_uri"

**Sửa**: Keycloak → Clients → minio → Settings
```
Valid redirect URIs: http://localhost:8088/minio/*
```
Save lại.

### Lỗi: "Invalid client credentials"

**Sửa**: 
1. Copy lại Client Secret từ Keycloak
2. Cập nhật vào `docker-compose.yml`
3. Restart MinIO

### Lỗi: Không truy cập được Keycloak

**Kiểm tra**:
```powershell
docker ps | Select-String "auth"
```

Nếu không chạy:
```powershell
docker compose up -d auth
```

---

## ✅ Checklist

- [ ] Truy cập được http://localhost:8088/auth/
- [ ] Đăng nhập Keycloak Admin với username `admin`
- [ ] Chọn realm `realm_52300267`
- [ ] Tạo client `minio` với Client authentication ON
- [ ] Copy Client Secret
- [ ] Cập nhật secret vào `docker-compose.yml`
- [ ] Restart MinIO (chạy `restart-minio.ps1`)
- [ ] Truy cập http://localhost:8088/minio/
- [ ] Thấy button "Login with SSO"
- [ ] Click button và test thành công

---

## 📚 Tài liệu chi tiết

Nếu cần hướng dẫn chi tiết hơn:
- **Hướng dẫn thực tế**: `HUONG_DAN_THUC_TE.md`
- **Setup đầy đủ**: `MINIO_SSO_SETUP.md`
- **Flow diagrams**: `SSO_FLOW_DIAGRAM.md`

---

## 🎯 Kết quả cuối cùng

Sau khi hoàn thành:
- ✅ Đăng nhập website → Truy cập MinIO → Tự động authenticated
- ✅ Không cần nhập lại password
- ✅ Quản lý user tập trung qua Keycloak

**Good luck! 🚀**

---

**Thời gian**: 10 phút  
**Độ khó**: ⭐⭐☆☆☆
