# 🔐 MinIO Authentication - Đơn giản như Prometheus

## ✅ Cách hoạt động (Giống Prometheus)

### Luồng đăng nhập

```
1. User đăng nhập vào website
   → Flask tạo token và lưu vào Redis
   → Set cookie: mc_token=<token>

2. User truy cập MinIO Console: http://localhost:8088/minio/
   → Nginx gọi auth_request /_auth_check
   → Flask kiểm tra cookie mc_token trong Redis
   
3. Nếu token hợp lệ:
   → Nginx cho phép truy cập MinIO
   → MinIO hiển thị trang login
   → User nhập MinIO credentials (root user)
   → Vào MinIO Console
   
4. Nếu token không hợp lệ:
   → Nginx trả về 401
   → Redirect đến trang login website
```

**Giống Prometheus**:
- ✅ Phải đăng nhập website trước (có cookie)
- ✅ Sau đó mới vào được service
- ✅ Service có credentials riêng (MinIO root user)

**Khác với auto-login hoàn toàn**:
- ❌ Không tự động điền username/password MinIO
- ✅ User phải nhập credentials MinIO thủ công
- ✅ Bảo mật hơn - không lưu password MinIO trong cookie

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

**Kết quả**: Cookie `mc_token` được set

### Bước 2: Truy cập MinIO

```
URL: http://localhost:8088/minio/
```

**Kết quả mong đợi**:
- ✅ Nginx kiểm tra cookie → OK
- ✅ Cho phép truy cập MinIO
- ✅ MinIO hiển thị trang login
- ✅ **Không tự động đăng nhập** (đây là behavior đúng!)

### Bước 3: Đăng nhập MinIO

```
Username: admin
Password: minio_admin_secret_123!
```

(Xem trong `MiniCloud/secrets/storage_root_user.txt` và `storage_root_pass.txt`)

**Kết quả**:
- ✅ Vào MinIO Console
- ✅ Quản lý buckets, files, users, policies

### Bước 4: Nếu chưa đăng nhập website

```
URL: http://localhost:8088/minio/
```

**Kết quả**:
- ❌ Nginx kiểm tra cookie → Không có
- ❌ Trả về 401 Unauthorized
- 🔄 Redirect đến trang login website
- ✅ Sau khi login website → quay lại bước 2

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

### 2. Consistent với Prometheus
- Cùng cơ chế: cookie-based access control
- Phải đăng nhập website trước
- Service có credentials riêng

### 3. Bảo mật
- 2-layer authentication:
  - Layer 1: Website authentication (cookie)
  - Layer 2: MinIO authentication (root credentials)
- Không lưu MinIO password trong cookie
- Phân quyền rõ ràng

### 4. Dễ maintain
- Ít config hơn
- Ít secret hơn
- Ít lỗi hơn

---

## ❓ FAQ

### Q: Tại sao MinIO vẫn có trang đăng nhập?

**A**: Đây là behavior đúng! Giống Prometheus:
- Cookie `mc_token` chỉ cho phép **truy cập** service
- Không tự động đăng nhập vào service
- User phải nhập credentials của service (MinIO root user)

### Q: Có thể tự động đăng nhập MinIO không?

**A**: Có thể, nhưng không khuyến nghị vì:
- ❌ Phải lưu MinIO password trong cookie (không bảo mật)
- ❌ Hoặc phải tạo MinIO user tự động (phức tạp)
- ✅ Cách hiện tại đơn giản và bảo mật hơn

### Q: Khác gì với OIDC SSO?

**A**: 
- **OIDC SSO**: Tự động đăng nhập MinIO bằng Keycloak (phức tạp)
- **Cookie auth**: Chỉ kiểm tra access, user tự đăng nhập MinIO (đơn giản)

### Q: MinIO credentials là gì?

**A**: 
- Username: `admin` (trong `secrets/storage_root_user.txt`)
- Password: `minio_admin_secret_123!` (trong `secrets/storage_root_pass.txt`)

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
