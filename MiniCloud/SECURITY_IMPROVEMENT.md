# 🔐 Cải thiện bảo mật - Docker Secrets cho MinIO OIDC

## ❌ Vấn đề trước đây

Client Secret bị **hardcode** trong `docker-compose.yml`:

```yaml
environment:
  MINIO_IDENTITY_OPENID_CLIENT_SECRET: "xbyxCAD1SlpBy937eMLVtJSQ33udpLfT"
```

**Rủi ro**:
- ❌ Secret bị commit lên Git (public repository)
- ❌ Ai cũng có thể đọc được secret
- ❌ Khó thay đổi khi cần rotate secret
- ❌ Không theo best practice

---

## ✅ Giải pháp: Docker Secrets

### Cách hoạt động

1. **Secret được lưu trong file riêng**: `secrets/minio_oidc_client_secret.txt`
2. **File nằm trong `.gitignore`**: Không bị commit lên Git
3. **Docker mount secret vào container**: `/run/secrets/minio_oidc_client_secret`
4. **MinIO đọc từ file**: `MINIO_IDENTITY_OPENID_CLIENT_SECRET_FILE`

### Cấu hình mới

**docker-compose.yml**:
```yaml
secrets:
  minio_oidc_client_secret:
    file: ./secrets/minio_oidc_client_secret.txt

services:
  storage:
    secrets:
      - minio_oidc_client_secret
    environment:
      # Thay vì hardcode:
      # MINIO_IDENTITY_OPENID_CLIENT_SECRET: "xbyxCAD1..."
      
      # Dùng file:
      MINIO_IDENTITY_OPENID_CLIENT_SECRET_FILE: /run/secrets/minio_oidc_client_secret
```

**.gitignore**:
```
MiniCloud/secrets/*.txt
```

---

## 📋 Cách sử dụng

### Bước 1: Lấy Client Secret từ Keycloak

1. Truy cập: http://localhost:8088/auth/
2. Realm: `realm_52300267`
3. Clients → `minio` → Tab **Credentials**
4. Copy **Client secret**

### Bước 2: Tạo secret file

**PowerShell (Windows)**:
```powershell
cd MiniCloud/secrets
"xbyxCAD1SlpBy937eMLVtJSQ33udpLfT" | Out-File -NoNewline -Encoding ASCII minio_oidc_client_secret.txt
```

**Bash (Linux/Mac)**:
```bash
cd MiniCloud/secrets
echo -n "xbyxCAD1SlpBy937eMLVtJSQ33udpLfT" > minio_oidc_client_secret.txt
```

**Lưu ý**: Dùng `-n` hoặc `-NoNewline` để không thêm newline ở cuối file.

### Bước 3: Kiểm tra file

```powershell
Get-Content secrets/minio_oidc_client_secret.txt
```

Phải hiển thị đúng Client Secret, không có khoảng trắng hay newline thừa.

### Bước 4: Restart MinIO

```powershell
docker compose restart storage
```

---

## 🔒 Bảo mật

### ✅ Ưu điểm

1. **Secret không bị commit lên Git**
   - File nằm trong `.gitignore`
   - Chỉ tồn tại local trên máy dev

2. **Dễ rotate secret**
   - Chỉ cần thay đổi nội dung file
   - Restart container để áp dụng

3. **Theo best practice**
   - Docker Secrets là cách khuyến nghị
   - Tương tự với các secret khác (DB password, Keycloak password)

4. **Phân quyền rõ ràng**
   - Chỉ container `storage` có quyền đọc secret
   - Secret được mount read-only vào `/run/secrets/`

### 🔐 So sánh với các phương pháp khác

| Phương pháp | Bảo mật | Dễ dùng | Best Practice |
|-------------|---------|---------|---------------|
| **Hardcode trong docker-compose.yml** | ❌ Kém | ✅ Dễ | ❌ Không |
| **Environment variable** | ⚠️ Trung bình | ✅ Dễ | ⚠️ OK |
| **Docker Secrets (file)** | ✅ Tốt | ✅ Dễ | ✅ Có |
| **Docker Secrets (Swarm)** | ✅ Rất tốt | ⚠️ Phức tạp | ✅ Có |
| **External secret manager** | ✅ Rất tốt | ❌ Khó | ✅ Có |

---

## 📊 Danh sách Secrets trong hệ thống

| Secret File | Mô tả | Dùng bởi |
|-------------|-------|----------|
| `db_root_password.txt` | MariaDB root password | `db` |
| `db_password.txt` | MariaDB user password | `db`, `auth`, `app`, `app2` |
| `kc_admin_password.txt` | Keycloak admin password | `auth` |
| `storage_root_user.txt` | MinIO root username | `storage` |
| `storage_root_pass.txt` | MinIO root password | `storage` |
| `minio_oidc_client_secret.txt` | MinIO OIDC Client Secret | `storage` |

---

## 🔄 Rotate Secret

Khi cần thay đổi Client Secret:

### Bước 1: Regenerate secret trong Keycloak

1. Keycloak Admin → Clients → `minio` → Credentials
2. Click **Regenerate** → Copy secret mới

### Bước 2: Cập nhật secret file

```powershell
"NEW_CLIENT_SECRET" | Out-File -NoNewline -Encoding ASCII secrets/minio_oidc_client_secret.txt
```

### Bước 3: Restart MinIO

```powershell
docker compose restart storage
```

**Không cần** thay đổi `docker-compose.yml`!

---

## 🧪 Testing

### Kiểm tra secret đã được mount chưa

```powershell
docker exec minicloud-storage cat /run/secrets/minio_oidc_client_secret
```

Phải hiển thị Client Secret.

### Kiểm tra MinIO đã đọc secret chưa

```powershell
docker logs minicloud-storage 2>&1 | Select-String "OpenID"
```

Nếu thành công, sẽ thấy:
```
API: SYSTEM() OpenID Connect is configured
```

---

## 📚 Tài liệu tham khảo

- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [MinIO Identity Management](https://min.io/docs/minio/linux/operations/external-iam/configure-openid-external-identity-management.html)
- [12-Factor App - Config](https://12factor.net/config)

---

## ✅ Checklist Migration

- [x] Tạo file `secrets/minio_oidc_client_secret.txt`
- [x] Thêm secret vào `docker-compose.yml` (secrets section)
- [x] Mount secret vào container `storage`
- [x] Thay `MINIO_IDENTITY_OPENID_CLIENT_SECRET` bằng `MINIO_IDENTITY_OPENID_CLIENT_SECRET_FILE`
- [x] Kiểm tra `.gitignore` đã ignore `secrets/*.txt`
- [x] Cập nhật documentation
- [x] Test restart container

---

**Version**: 2.2  
**Date**: April 15, 2026  
**Status**: ✅ Implemented
