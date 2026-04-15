# 📖 MinIO SSO Documentation

## 🎯 Bắt đầu từ đây

**Đọc file này trước**: [`BAT_DAU_O_DAY.md`](./BAT_DAU_O_DAY.md)

Hướng dẫn ngắn gọn, từng bước với screenshots mô tả.

---

## 📚 Tài liệu đầy đủ

### 1. Quick Start (5-10 phút)
- **File**: [`BAT_DAU_O_DAY.md`](./BAT_DAU_O_DAY.md)
- **Nội dung**: Hướng dẫn từng bước với screenshots
- **Dành cho**: Người mới bắt đầu

### 2. Hướng dẫn thực tế
- **File**: [`HUONG_DAN_THUC_TE.md`](./HUONG_DAN_THUC_TE.md)
- **Nội dung**: Giải quyết vấn đề thực tế, troubleshooting
- **Dành cho**: Khi gặp lỗi hoặc cần debug

### 3. Setup đầy đủ
- **File**: [`MINIO_SSO_SETUP.md`](./MINIO_SSO_SETUP.md)
- **Nội dung**: Hướng dẫn chi tiết, cấu hình nâng cao
- **Dành cho**: Hiểu sâu về OIDC và Keycloak

### 4. Flow Diagrams
- **File**: [`SSO_FLOW_DIAGRAM.md`](./SSO_FLOW_DIAGRAM.md)
- **Nội dung**: Sequence diagrams, kiến trúc SSO
- **Dành cho**: Hiểu luồng xác thực

### 5. Quick Reference
- **File**: [`QUICK_START_SSO.md`](./QUICK_START_SSO.md)
- **Nội dung**: Tóm tắt nhanh các bước
- **Dành cho**: Người đã biết, cần nhắc lại

### 6. Next Steps
- **File**: [`NEXT_STEPS.md`](./NEXT_STEPS.md)
- **Nội dung**: Checklist các bước tiếp theo
- **Dành cho**: Theo dõi tiến độ

---

## 🛠️ Scripts hỗ trợ

### 1. PowerShell Script (Windows)
```powershell
.\restart-minio.ps1
```
- Tự động restart MinIO với cấu hình mới
- Kiểm tra OIDC config
- Hiển thị logs

### 2. Bash Script (Linux/Mac)
```bash
chmod +x setup-minio-sso.sh
./setup-minio-sso.sh
```
- Hướng dẫn tạo Keycloak client
- Cập nhật Client Secret
- Restart MinIO

---

## 🔑 Thông tin quan trọng

### Keycloak Admin Console
```
URL: http://localhost:8088/auth/
Username: admin
Password: keycloak_admin_super_secret_123!
```

### Realm
```
realm_52300267
```

### Test User
```
Username: testuser
Password: Test@123
```

### MinIO Root User
```
Username: admin
Password: minio_admin_secret_123!
```

---

## ⚡ Quick Commands

### Restart MinIO
```powershell
cd MiniCloud
docker compose restart storage
```

### Check OIDC Config
```powershell
docker exec minicloud-storage env | Select-String "MINIO_IDENTITY"
```

### View Logs
```powershell
docker logs minicloud-storage -f
```

### Check Container Status
```powershell
docker ps | Select-String "storage"
```

---

## ✅ Checklist

- [ ] Đọc `BAT_DAU_O_DAY.md`
- [ ] Truy cập Keycloak Admin Console
- [ ] Tạo client `minio` trong realm `realm_52300267`
- [ ] Copy Client Secret
- [ ] Cập nhật `docker-compose.yml`
- [ ] Chạy `restart-minio.ps1`
- [ ] Truy cập http://localhost:8088/minio/
- [ ] Thấy button "Login with SSO"
- [ ] Test SSO thành công

---

## 🆘 Cần giúp đỡ?

### Vấn đề thường gặp

1. **Không thấy button "Login with SSO"**
   → Đọc: `HUONG_DAN_THUC_TE.md` → Troubleshooting → Vấn đề 1

2. **"Invalid redirect_uri"**
   → Đọc: `HUONG_DAN_THUC_TE.md` → Troubleshooting → Vấn đề 2

3. **"Invalid client credentials"**
   → Đọc: `HUONG_DAN_THUC_TE.md` → Troubleshooting → Vấn đề 3

4. **Không truy cập được Keycloak**
   → Đọc: `HUONG_DAN_THUC_TE.md` → Troubleshooting → Vấn đề 4

---

## 📊 Tài liệu khác

- **Kiến trúc hệ thống**: `ARCHITECTURE_SUMMARY.md`
- **Changelog**: `CHANGELOG.md`
- **System check**: `KIEM_TRA_HE_THONG.md`
- **Main README**: `README.md`

---

**Version**: 2.1  
**Last Updated**: April 15, 2026  
**Status**: ✅ Ready to use
