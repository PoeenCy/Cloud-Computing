# 📖 Hướng dẫn sử dụng MinIO Console

## 🎯 Cách truy cập MinIO (2 bước)

### Bước 1: Đăng nhập Website

```
URL: http://localhost:8088/
Username: testuser
Password: Test@123
```

**Kết quả**: Bạn có cookie `mc_token` → Được phép truy cập các service

---

### Bước 2: Truy cập MinIO Console

```
URL: http://localhost:8088/minio/
```

**Bạn sẽ thấy trang login MinIO**:

```
┌─────────────────────────────────┐
│   MinIO Object Store            │
│   Community Edition             │
├─────────────────────────────────┤
│                                 │
│   Username: [________]          │
│   Password: [________]          │
│                                 │
│   [Login]                       │
└─────────────────────────────────┘
```

**Nhập credentials**:
- **Username**: `admin`
- **Password**: `minio_admin_secret_123!`

(Xem trong `MiniCloud/secrets/storage_root_user.txt` và `storage_root_pass.txt`)

**Click Login** → Vào MinIO Console!

---

## ✅ Đây là behavior đúng!

### Tại sao phải đăng nhập 2 lần?

**2-layer authentication**:

1. **Layer 1 - Website authentication**:
   - Kiểm tra bạn có quyền truy cập hệ thống không
   - Dùng cookie `mc_token`
   - Giống như security checkpoint ở cổng

2. **Layer 2 - MinIO authentication**:
   - Kiểm tra bạn có quyền sử dụng MinIO không
   - Dùng MinIO root credentials
   - Giống như key phòng riêng

### Giống Prometheus

Prometheus cũng vậy:
- Phải đăng nhập website trước (có cookie)
- Sau đó mới vào được Prometheus
- Prometheus không cần login lại vì nó không có user management

MinIO khác:
- Có user management, policies, buckets
- Cần credentials riêng để quản lý
- Bảo mật hơn

---

## 🔐 MinIO Credentials

### Root User (Admin)

**Username**: `admin`  
**Password**: `minio_admin_secret_123!`

**Quyền**: Full admin - tạo buckets, users, policies, etc.

### Lấy credentials từ file

```powershell
# Username
Get-Content MiniCloud/secrets/storage_root_user.txt

# Password
Get-Content MiniCloud/secrets/storage_root_pass.txt
```

---

## 📦 Sử dụng MinIO Console

### 1. Quản lý Buckets

**Buckets** = Thư mục lưu trữ files

- Click **Buckets** trong sidebar
- Click **Create Bucket** để tạo mới
- Nhập tên bucket (ví dụ: `my-data`)
- Click **Create**

### 2. Upload Files

- Vào bucket
- Click **Upload** → **Upload File**
- Chọn file từ máy
- Click **Upload**

### 3. Quản lý Users

- Click **Identity** → **Users**
- Click **Create User**
- Nhập username, password
- Assign policies (quyền)
- Click **Save**

### 4. Quản lý Policies

**Policies** = Quyền truy cập (read, write, delete)

- Click **Identity** → **Policies**
- Click **Create Policy**
- Chọn template hoặc viết JSON
- Click **Save**

### 5. Access Keys (API)

Để dùng MinIO từ code (Python, Node.js, etc.):

- Click **Identity** → **Service Accounts**
- Click **Create Service Account**
- Copy **Access Key** và **Secret Key**
- Dùng trong code

---

## 🧪 Test Upload/Download

### Upload file test

1. Tạo bucket: `test-bucket`
2. Upload file: `test.txt`
3. File sẽ có URL: `http://localhost:8088/minio/browser/test-bucket/test.txt`

### Download file

- Click vào file trong bucket
- Click **Download**
- Hoặc dùng API với Access Key

---

## 🔍 Troubleshooting

### Vấn đề 1: Không vào được MinIO (401)

**Nguyên nhân**: Chưa đăng nhập website

**Giải pháp**:
1. Đăng nhập website: http://localhost:8088/
2. Sau đó mới vào MinIO: http://localhost:8088/minio/

### Vấn đề 2: Sai username/password MinIO

**Kiểm tra credentials**:
```powershell
Get-Content MiniCloud/secrets/storage_root_user.txt
Get-Content MiniCloud/secrets/storage_root_pass.txt
```

**Default**:
- Username: `admin`
- Password: `minio_admin_secret_123!`

### Vấn đề 3: MinIO không load

**Kiểm tra container**:
```powershell
docker ps | Select-String "storage"
```

Phải thấy: `minicloud-storage   Up ... (healthy)`

**Nếu không chạy**:
```powershell
docker compose up -d storage
```

---

## 📚 Tài liệu thêm

- **MinIO Documentation**: https://min.io/docs/minio/linux/index.html
- **MinIO Console Guide**: https://min.io/docs/minio/linux/administration/minio-console.html
- **MinIO Client (mc)**: https://min.io/docs/minio/linux/reference/minio-mc.html

---

## 💡 Tips

### 1. Tạo user cho từng người

Không nên share root credentials. Tạo user riêng:

1. **Identity** → **Users** → **Create User**
2. Assign policy phù hợp (readwrite, readonly, etc.)
3. Mỗi người dùng user riêng

### 2. Sử dụng Service Accounts cho apps

Không dùng root credentials trong code. Tạo Service Account:

1. **Identity** → **Service Accounts** → **Create**
2. Copy Access Key và Secret Key
3. Dùng trong code

### 3. Backup buckets

MinIO không tự động backup. Nên:

- Export data định kỳ
- Hoặc dùng MinIO replication
- Hoặc backup volume Docker

### 4. Monitor storage

- Click **Monitoring** → **Metrics**
- Xem storage usage, bandwidth, requests
- Set alerts nếu cần

---

## ✅ Checklist

- [ ] Đăng nhập website (testuser / Test@123)
- [ ] Truy cập MinIO Console (http://localhost:8088/minio/)
- [ ] Đăng nhập MinIO (admin / minio_admin_secret_123!)
- [ ] Tạo bucket test
- [ ] Upload file test
- [ ] Download file test
- [ ] Tạo user mới (optional)
- [ ] Tạo Service Account (optional)

---

**Happy storing! 📦🚀**
