# 🔐 MinIO Authentication - Đơn giản như Prometheus

## ✅ Cách hoạt động (Giống Prometheus)

### Luồng đăng nhập tự động

```
1. User đăng nhập vào website
   → Flask tạo token và lưu vào Redis
   → Set cookie: mc_token=<token>

2. User truy cập MinIO Console: http://localhost:8088/minio/
   → Nginx gọi auth_request /_auth_check
   → Flask kiểm tra cookie mc_token trong Redis
   
3. Nếu token hợp lệ:
   → Nginx cho phép truy cập MinIO
   → User vào MinIO Console tự động
   
4. Nếu token không hợp lệ:
   → Nginx trả về 401
   → Redirect đến trang login
```

**Kết quả**: Đăng nhập 1 lần → Dùng được cả Website, Prometheus, và MinIO!

---

## 🎯 So sánh với cách cũ (OIDC SSO)

| Aspect | OIDC SSO (Cũ) | Cookie Auth (Mới) |
|--------|---------------|-------------------|
| **Độ phức tạp** | ❌ Rất phức tạp | ✅ Đơn giản |
| **Setup** | Phải tạo Keycloak client | Không cần |
| **Client Secret** | Phải quản lý | Không cần |
| **User experience** | Click "Login with SSO" | Tự động đăng nhập |
| **Consistent** | ❌ Khác Prometheus | ✅ Giống Prometheus |
| **Maintenance** | ❌ Khó | ✅ Dễ |

---

## 📋 Cấu hình

### Nginx (giống Prometheus)

```nginx
location /minio/ {
    # Kiểm tra cookie mc_token
    auth_request /_auth_check;
    
    proxy_pass http://10.10.2.15:9001/;
    # ... các header khác
}
```

### MinIO (đơn giản)

```yaml
environment:
  MINIO_ROOT_USER_FILE: /run/secrets/storage_root_user
  MINIO_ROOT_PASSWORD_FILE: /run/secrets/storage_root_pass
  MINIO_BROWSER_REDIRECT_URL: "http://localhost:8088/minio/"
```

**Không cần**:
- ❌ OIDC config URL
- ❌ Client ID
- ❌ Client Secret
- ❌ Scopes
- ❌ Redirect URI
- ❌ Claim mapping

---

## 🧪 Test

### Bước 1: Đăng nhập vào website

```
URL: http://localhost:8088/
Username: testuser
Password: Test@123
```

### Bước 2: Truy cập MinIO

```
URL: http://localhost:8088/minio/
```

**Kết quả mong đợi**:
- ✅ Tự động vào MinIO Console
- ✅ Không cần nhập lại username/password
- ✅ Không có button "Login with SSO"
- ✅ Giống như Prometheus

### Bước 3: Nếu chưa đăng nhập

```
URL: http://localhost:8088/minio/
```

**Kết quả**:
- ❌ Nginx trả về 401
- 🔄 Redirect đến trang login
- ✅ Sau khi login → tự động vào MinIO

---

## 🔍 Troubleshooting

### Vấn đề 1: Vẫn phải nhập username/password

**Nguyên nhân**: Cookie `mc_token` không tồn tại hoặc đã hết hạn

**Giải pháp**:
1. Đăng nhập lại vào website
2. Kiểm tra cookie trong browser (F12 → Application → Cookies)
3. Phải thấy cookie `mc_token`

### Vấn đề 2: 401 Unauthorized

**Nguyên nhân**: Token không hợp lệ hoặc Redis không chạy

**Kiểm tra**:
```powershell
# Kiểm tra Redis
docker ps | Select-String "redis"

# Kiểm tra Flask auth endpoint
Invoke-WebRequest -Uri "http://localhost:8088/api/auth/me-cookie" -UseBasicParsing
```

### Vấn đề 3: MinIO không load

**Nguyên nhân**: Container không chạy hoặc Nginx config sai

**Kiểm tra**:
```powershell
# Container status
docker ps | Select-String "storage"

# Nginx config
docker exec minicloud-proxy nginx -t

# MinIO logs
docker logs minicloud-storage --tail 20
```

---

## 💡 Lợi ích

### 1. Đơn giản hơn
- Không cần Keycloak client
- Không cần quản lý Client Secret
- Không cần cấu hình OIDC phức tạp

### 2. Consistent
- Giống Prometheus
- Giống các service khác
- Cùng một cơ chế auth

### 3. User-friendly
- Tự động đăng nhập
- Không cần click button
- Seamless experience

### 4. Dễ maintain
- Ít config hơn
- Ít secret hơn
- Ít lỗi hơn

---

## 📊 Kiến trúc

```
┌─────────────────────────────────────────────────────────┐
│                    User Browser                         │
│  Cookie: mc_token=<token>                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx Proxy (10.10.1.10)                   │
│                                                          │
│  location /minio/ {                                     │
│    auth_request /_auth_check;  ← Kiểm tra cookie       │
│    proxy_pass http://10.10.2.15:9001/;                 │
│  }                                                       │
│                                                          │
│  location /_auth_check {                                │
│    proxy_pass http://app_pool/api/auth/me-cookie;      │
│  }                                                       │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Flask App       │    │  MinIO Console   │
│  (10.10.1.12)    │    │  (10.10.2.15)    │
│                  │    │                  │
│  /api/auth/      │    │  Port: 9001      │
│  me-cookie       │    │                  │
│  ↓               │    └──────────────────┘
│  Check Redis     │
│  ↓               │
│  Return 200/401  │
└──────────────────┘
         ▼
┌──────────────────┐
│  Redis           │
│  (10.10.2.16)    │
│                  │
│  Token store     │
└──────────────────┘
```

---

## ✅ Checklist

- [x] Xóa OIDC config từ docker-compose.yml
- [x] Xóa minio_oidc_client_secret
- [x] Thêm auth_request vào nginx.conf
- [x] Restart MinIO container
- [x] Reload Nginx
- [x] Test đăng nhập tự động

---

## 🎯 Kết luận

**Trước**: Phức tạp, nhiều bước, phải tạo Keycloak client, quản lý secret

**Sau**: Đơn giản, tự động, giống Prometheus, dễ maintain

**User experience**: Đăng nhập 1 lần → Dùng được tất cả!

---

**Version**: 3.0 (Simplified)  
**Date**: April 15, 2026  
**Status**: ✅ Production Ready
