# 🚀 Hướng dẫn Deploy MiniCloud lên Google Cloud Platform

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Chuẩn bị](#chuẩn-bị)
3. [Bước 1: Tạo tài khoản GCP](#bước-1-tạo-tài-khoản-gcp)
4. [Bước 2: Cài đặt Google Cloud SDK](#bước-2-cài-đặt-google-cloud-sdk)
5. [Bước 3: Tạo VM trên GCP](#bước-3-tạo-vm-trên-gcp)
6. [Bước 4: Deploy ứng dụng](#bước-4-deploy-ứng-dụng)
7. [Bước 5: Truy cập và kiểm tra](#bước-5-truy-cập-và-kiểm-tra)
8. [Quản lý VM](#quản-lý-vm)
9. [Xử lý lỗi](#xử-lý-lỗi)

---

## Giới thiệu

### Bạn sẽ làm gì?
Deploy hệ thống MiniCloud (17 containers) lên Google Cloud Platform để demo đồ án.

### Thông tin cấu hình
- **Region:** Singapore (asia-southeast1) - gần Việt Nam, delay thấp ~20ms
- **VM:** e2-small (2 vCPU, 2GB RAM) - đủ cho demo
- **Chi phí:** ~$19/tháng hoặc **MIỄN PHÍ 15 tháng** với $300 credit
- **Thời gian:** 45-60 phút

### Yêu cầu
- Máy tính Windows/Mac/Linux
- Kết nối Internet
- Thẻ tín dụng (Visa/Mastercard) - **KHÔNG BỊ CHARGE** khi dùng Free Trial
- Email Gmail

---

## Chuẩn bị

### Những gì bạn cần có sẵn
1. ✅ Tài khoản Gmail
2. ✅ Thẻ tín dụng (để verify, không bị trừ tiền)
3. ✅ Project MiniCloud đã chạy được trên máy local
4. ✅ Git Bash (Windows) hoặc Terminal (Mac/Linux)

---

## Bước 1: Tạo tài khoản GCP

### 1.1. Đăng ký GCP

1. Mở trình duyệt, truy cập: **https://console.cloud.google.com/**

2. Click **"Get started for free"** hoặc **"Bắt đầu miễn phí"**

3. Đăng nhập bằng Gmail của bạn

4. Chọn quốc gia: **Vietnam**

5. Đồng ý với Terms of Service (đọc và tick vào ô)

### 1.2. Nhập thông tin thanh toán

1. Chọn **"Individual"** (Cá nhân)

2. Nhập thông tin:
   - Tên
   - Địa chỉ
   - Số điện thoại

3. Nhập thông tin thẻ tín dụng:
   - Số thẻ
   - Ngày hết hạn
   - CVV

   **⚠️ LƯU Ý:** Google sẽ charge $1-2 để verify thẻ, sau đó hoàn lại ngay. Bạn sẽ KHÔNG BỊ CHARGE thêm khi dùng Free Trial.

4. Click **"Start my free trial"**

### 1.3. Nhận $300 credit

Sau khi hoàn tất, bạn sẽ thấy:
- ✅ **$300 credit** (có hiệu lực 90 ngày)
- ✅ Dashboard GCP Console

**🎉 Chúc mừng! Bạn đã có tài khoản GCP với $300 credit!**

---

## Bước 2: Cài đặt Google Cloud SDK

### 2.1. Download Google Cloud SDK

#### Trên Windows:

1. Truy cập: **https://cloud.google.com/sdk/docs/install**

2. Click **"Download the Google Cloud CLI installer"**

3. Chọn phiên bản phù hợp:
   - Windows 64-bit: `GoogleCloudSDKInstaller.exe`

4. Chạy file installer vừa download

5. Trong quá trình cài đặt:
   - ✅ Tick "Run 'gcloud init'"
   - ✅ Tick "Install Bundled Python"

6. Click **"Install"** và đợi hoàn tất

#### Trên Mac:

```bash
# Dùng Homebrew
brew install google-cloud-sdk
```

#### Trên Linux:

```bash
# Download và cài đặt
curl https://sdk.cloud.google.com | bash

# Restart shell
exec -l $SHELL
```

### 2.2. Khởi tạo gcloud

1. Mở **Git Bash** (Windows) hoặc **Terminal** (Mac/Linux)

2. Chạy lệnh:
```bash
gcloud init
```

3. Bạn sẽ thấy câu hỏi:
```
You must log in to continue. Would you like to log in (Y/n)?
```
→ Gõ **Y** và Enter

4. Trình duyệt sẽ mở, chọn tài khoản Gmail của bạn

5. Click **"Allow"** để cho phép gcloud truy cập

6. Quay lại Terminal, bạn sẽ thấy:
```
You are logged in as: [your-email@gmail.com]
```

7. Chọn hoặc tạo project:
```
Pick cloud project to use:
 [1] Create a new project
 [2] [existing-project-id]
```
→ Gõ **1** để tạo project mới

8. Nhập tên project:
```
Enter a Project ID:
```
→ Gõ: **minicloud-demo** (hoặc tên bạn thích)

9. Chọn region:
```
Do you want to configure a default Compute Region and Zone? (Y/n)?
```
→ Gõ **Y**

10. Chọn region:
```
Please enter numeric choice or text value (must exactly match list item):
```
→ Tìm và chọn: **asia-southeast1** (Singapore)
→ Ví dụ: Gõ **11** (số thứ tự của asia-southeast1)

11. Chọn zone:
```
Please enter numeric choice or text value (must exactly match list item):
```
→ Chọn: **asia-southeast1-a**
→ Ví dụ: Gõ **1**

12. Hoàn tất! Bạn sẽ thấy:
```
Your Google Cloud SDK is configured!
```

### 2.3. Kiểm tra cài đặt

```bash
# Kiểm tra version
gcloud --version

# Kiểm tra project hiện tại
gcloud config list

# Kết quả mong đợi:
# [core]
# account = your-email@gmail.com
# project = minicloud-demo
# [compute]
# region = asia-southeast1
# zone = asia-southeast1-a
```

**✅ Hoàn tất! Google Cloud SDK đã sẵn sàng!**

---

## Bước 3: Tạo VM trên GCP

### 3.1. Enable Compute Engine API

```bash
gcloud services enable compute.googleapis.com
```

Đợi khoảng 30 giây. Bạn sẽ thấy:
```
Operation "operations/..." finished successfully.
```

### 3.2. Tạo Firewall Rules

```bash
# Cho phép HTTP (port 80)
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server \
  --description="Allow HTTP traffic"

# Cho phép HTTPS (port 443)
gcloud compute firewall-rules create allow-https \
  --allow=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=https-server \
  --description="Allow HTTPS traffic"
```

Bạn sẽ thấy:
```
Created [https://www.googleapis.com/compute/v1/projects/.../firewalls/allow-http].
```

### 3.3. Tạo VM Instance

**⚠️ QUAN TRỌNG:** Lệnh khác nhau tùy theo hệ điều hành

#### Trên Windows (Git Bash hoặc PowerShell):

**Cách 1: Tạo VM không có startup script (KHUYẾN NGHỊ)**

```bash
gcloud compute instances create minicloud-demo --machine-type=e2-small --zone=asia-southeast1-a --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud --boot-disk-size=30GB --boot-disk-type=pd-standard --network-tier=STANDARD --tags=http-server,https-server
```

**Cách 2: Dùng file startup script**

Tạo file `startup.sh`:
```bash
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git
systemctl enable docker
systemctl start docker
```

Sau đó chạy:
```bash
gcloud compute instances create minicloud-demo --machine-type=e2-small --zone=asia-southeast1-a --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud --boot-disk-size=30GB --boot-disk-type=pd-standard --network-tier=STANDARD --tags=http-server,https-server --metadata-from-file=startup-script=startup.sh
```

#### Trên Mac/Linux:

```bash
gcloud compute instances create minicloud-demo \
  --machine-type=e2-small \
  --zone=asia-southeast1-a \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-standard \
  --network-tier=STANDARD \
  --tags=http-server,https-server \
  --metadata=startup-script='#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git
systemctl enable docker
systemctl start docker
'
```

**Giải thích lệnh:**
- `minicloud-demo`: Tên VM
- `e2-small`: Loại máy (2 vCPU, 2GB RAM)
- `asia-southeast1-a`: Zone ở Singapore
- `ubuntu-2204-lts`: Ubuntu 22.04
- `30GB`: Dung lượng disk
- `STANDARD`: Network tier (rẻ hơn)
- `startup-script`: Script tự động cài Docker khi VM khởi động

Quá trình tạo VM mất khoảng **2-3 phút**. Bạn sẽ thấy:
```
Created [https://www.googleapis.com/compute/v1/projects/.../instances/minicloud-demo].
NAME            ZONE               MACHINE_TYPE  INTERNAL_IP  EXTERNAL_IP    STATUS
minicloud-demo  asia-southeast1-a  e2-small      10.x.x.x     x.x.x.x        RUNNING
```

### 3.4. Lấy IP của VM

```bash
gcloud compute instances describe minicloud-demo \
  --zone=asia-southeast1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

Bạn sẽ thấy IP, ví dụ: `34.87.123.45`

**📝 LƯU LẠI IP NÀY!** Bạn sẽ dùng để truy cập website.

### 3.5. Cài đặt Docker trên VM

Vì startup script có thể không chạy được trên Windows, chúng ta sẽ cài Docker thủ công:

```bash
# SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

Trong VM, chạy các lệnh sau:

```bash
# Update system
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io docker-compose git

# Enable và start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Check Docker
sudo docker --version
sudo docker-compose --version

# Thêm user vào docker group (để không cần sudo)
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Test Docker
docker ps
```

Bạn sẽ thấy:
```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

**✅ Docker đã sẵn sàng!**

Giữ nguyên cửa sổ SSH này, chúng ta sẽ dùng ở bước tiếp theo.

---

## Bước 4: Deploy ứng dụng

### 4.1. Copy project lên VM

**MỞ CỬA SỔ TERMINAL MỚI** (giữ nguyên cửa sổ SSH cũ)

Từ thư mục gốc của project (nơi có folder `MiniCloud`):

```bash
# Copy toàn bộ folder MiniCloud lên VM
gcloud compute scp --recurse ./MiniCloud minicloud-demo:~/ --zone=asia-southeast1-a
```

Quá trình copy mất khoảng **2-5 phút** tùy tốc độ mạng.

Bạn sẽ thấy:
```
Copying files to minicloud-demo:~/MiniCloud
...
app.py                                          100%  1234    12.3KB/s   00:00
docker-compose.yml                              100%  5678    56.7KB/s   00:00
...
```

### 4.2. Quay lại cửa sổ SSH

Quay lại cửa sổ terminal đang SSH vào VM (từ bước 3.5).

Nếu đã thoát, SSH lại:
```bash
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

### 4.3. Chuẩn bị secrets

Trong VM, chạy các lệnh sau:

```bash
cd ~/MiniCloud

# Tạo secrets directory
mkdir -p secrets

# Tạo các secret files
echo "db_root_pass_123" > secrets/db_root_password.txt
echo "db_pass_123" > secrets/db_password.txt
echo "kc_admin_123" > secrets/kc_admin_password.txt
echo "minioadmin" > secrets/storage_root_user.txt
echo "minioadmin123" > secrets/storage_root_pass.txt

# Set permissions
chmod 600 secrets/*
```

### 4.4. Tạo file .env

```bash
cat > .env << EOF
DB_NAME=minicloud
DB_USER=admin
REDIS_PASSWORD=redis_secret_123
EOF
```

### 4.5. Sửa port trong docker-compose.yml

```bash
# Đổi port 8088:80 thành 80:80
sed -i 's/8088:80/80:80/g' docker-compose.yml

# Kiểm tra
grep "80:80" docker-compose.yml
```

Bạn sẽ thấy:
```
      - "80:80"
```

### 4.6. Start containers

```bash
docker-compose up -d
```

Quá trình pull images và start containers mất khoảng **5-10 phút**.

Bạn sẽ thấy:
```
Creating network "minicloud_frontend-net" ... done
Creating network "minicloud_backend-net" ... done
Creating network "minicloud_mgmt-net" ... done
Creating minicloud-dns ... done
Creating minicloud-db ... done
Creating minicloud-redis ... done
...
Creating minicloud-proxy ... done
```

### 4.7. Kiểm tra containers

```bash
docker-compose ps
```

Đợi 2-3 phút để tất cả containers start. Bạn sẽ thấy:
```
NAME                    STATUS              PORTS
minicloud-app           Up 2 minutes        
minicloud-app2          Up 2 minutes        
minicloud-auth          Up 2 minutes        
minicloud-db            Up 3 minutes        
minicloud-dns           Up 3 minutes        
minicloud-grafana       Up 2 minutes        
minicloud-loki          Up 2 minutes        
minicloud-monitoring    Up 2 minutes        
minicloud-nginx-exporter Up 2 minutes       
minicloud-node-exporter Up 2 minutes        
minicloud-proxy         Up 2 minutes        0.0.0.0:80->80/tcp
minicloud-promtail      Up 2 minutes        
minicloud-redis         Up 3 minutes        
minicloud-storage       Up 3 minutes        
minicloud-web1          Up 2 minutes        
minicloud-web2          Up 2 minutes        
```

**✅ Tất cả containers đã chạy!**

### 4.8. Thoát khỏi VM

```bash
exit
```

Bạn sẽ quay lại terminal máy local.

---

## Bước 5: Truy cập và kiểm tra

### 5.1. Lấy IP của VM (nếu quên)

```bash
VM_IP=$(gcloud compute instances describe minicloud-demo \
  --zone=asia-southeast1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "VM IP: $VM_IP"
```

### 5.2. Truy cập các services

Mở trình duyệt và truy cập:

#### Website chính
```
http://YOUR_VM_IP/
```
Bạn sẽ thấy trang chủ với blog cá nhân.

#### API
```
http://YOUR_VM_IP/api/hello
```
Bạn sẽ thấy JSON response:
```json
{
  "message": "Hello from Flask API - Instance 1",
  "timestamp": "2026-04-16T..."
}
```

#### Keycloak Admin
```
http://YOUR_VM_IP/auth/admin
```
- Username: `admin`
- Password: `kc_admin_123` (hoặc password bạn đã set trong secrets)

#### Grafana
```
http://YOUR_VM_IP/grafana/
```
- Username: `admin`
- Password: `admin`

#### Prometheus (cần login website trước)
```
http://YOUR_VM_IP/prometheus/
```

#### MinIO Console (cần login website trước)
```
http://YOUR_VM_IP/minio/
```
- Username: `minioadmin`
- Password: `minioadmin123`

### 5.3. Test API với curl

```bash
# Test API
curl http://YOUR_VM_IP/api/hello

# Test load balancing (gọi nhiều lần)
for i in {1..6}; do
  curl -s http://YOUR_VM_IP/api/hello | grep "Instance"
done
```

Bạn sẽ thấy response xen kẽ giữa Instance 1 và Instance 2 (load balancing).

**🎉 Hoàn tất! Hệ thống đã chạy trên GCP!**

---

## Quản lý VM

### Xem thông tin VM

```bash
# Xem tất cả VMs
gcloud compute instances list

# Xem chi tiết VM
gcloud compute instances describe minicloud-demo --zone=asia-southeast1-a
```

### Tắt VM (tiết kiệm chi phí)

```bash
gcloud compute instances stop minicloud-demo --zone=asia-southeast1-a
```

**Khi nào tắt VM?**
- Sau khi demo xong
- Khi không sử dụng (buổi tối, cuối tuần)

**Chi phí khi tắt:** ~$1/tháng (chỉ trả tiền disk)

### Bật VM

```bash
gcloud compute instances start minicloud-demo --zone=asia-southeast1-a
```

Đợi 2-3 phút để VM khởi động và containers start lại.

### SSH vào VM

```bash
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

### Xem logs containers

```bash
# SSH vào VM trước
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Trong VM:
cd ~/MiniCloud
docker-compose logs -f

# Xem logs của 1 container cụ thể
docker-compose logs -f minicloud-app

# Thoát logs: Ctrl + C
```

### Restart containers

```bash
# SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Restart tất cả
cd ~/MiniCloud
docker-compose restart

# Restart 1 container
docker-compose restart minicloud-app
```

### Xóa VM (sau khi hoàn thành đồ án)

```bash
# Tạo backup trước (optional)
gcloud compute disks snapshot minicloud-demo \
  --snapshot-names=minicloud-final-backup \
  --zone=asia-southeast1-a

# Xóa VM
gcloud compute instances delete minicloud-demo --zone=asia-southeast1-a
```

Bạn sẽ thấy:
```
Do you want to continue (Y/n)?
```
→ Gõ **Y**

**⚠️ LƯU Ý:** Sau khi xóa VM, bạn không thể khôi phục. Hãy chắc chắn đã backup nếu cần.

---

## Xử lý lỗi

### Lỗi 1: "gcloud: command not found"

**Nguyên nhân:** Chưa cài Google Cloud SDK

**Giải pháp:**
1. Cài lại Google Cloud SDK theo [Bước 2](#bước-2-cài-đặt-google-cloud-sdk)
2. Restart terminal
3. Chạy `gcloud init`

### Lỗi 2: "Permission denied" khi SSH

**Nguyên nhân:** SSH keys chưa được tạo

**Giải pháp:**
```bash
# Tạo SSH keys
gcloud compute config-ssh

# Thử SSH lại
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

### Lỗi 3: VM không start được

**Nguyên nhân:** Hết quota hoặc chưa enable APIs

**Giải pháp:**
```bash
# Check quota
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Enable APIs
gcloud services enable compute.googleapis.com

# Xem logs
gcloud compute instances get-serial-port-output minicloud-demo --zone=asia-southeast1-a
```

### Lỗi 4: Không truy cập được website

**Nguyên nhân:** Firewall chưa được cấu hình hoặc containers chưa start

**Giải pháp:**

```bash
# 1. Check firewall
gcloud compute firewall-rules list

# 2. Tạo lại firewall nếu cần
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server

# 3. Check containers
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
cd ~/MiniCloud
docker-compose ps

# 4. Test từ VM
curl localhost:80

# 5. Restart containers nếu cần
docker-compose restart
```

### Lỗi 5: Containers không chạy

**Nguyên nhân:** Docker chưa start hoặc hết disk space

**Giải pháp:**

```bash
# SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Check Docker
sudo systemctl status docker

# Restart Docker nếu cần
sudo systemctl restart docker

# Check disk space
df -h

# Xóa images không dùng (nếu hết disk)
docker system prune -a

# Restart containers
cd ~/MiniCloud
docker-compose down
docker-compose up -d
```

### Lỗi 6: "Error: (gcloud.compute.instances.create) Could not fetch resource"

**Nguyên nhân:** Region/zone không hợp lệ hoặc chưa enable APIs

**Giải pháp:**

```bash
# Set lại region và zone
gcloud config set compute/region asia-southeast1
gcloud config set compute/zone asia-southeast1-a

# Enable APIs
gcloud services enable compute.googleapis.com

# Thử tạo VM lại
```

### Lỗi 7: Hết $300 credit

**Giải pháp:**

1. **Upgrade sang paid account** (tiếp tục dùng, trả theo usage)
2. **Xóa VM** và giữ snapshot làm bằng chứng
3. **Tạo account mới** (không khuyến nghị)

---

## 💰 Chi phí

### Chi phí dự kiến

| Tình huống | Chi phí/tháng |
|------------|---------------|
| **Chạy 24/7** | $19 |
| **Tắt khi không dùng** (16h/ngày) | ~$5 |
| **Chỉ giữ snapshot** | ~$1 |

### Với $300 Free Trial

| Cấu hình | Chạy được |
|----------|-----------|
| Chạy 24/7 | 15 tháng |
| Tắt khi không dùng | 60 tháng (5 năm) |

### Lịch sử sử dụng cho đồ án (1 tháng)

```
Tuần 1-2: Test và chuẩn bị ($10)
Tuần 3: Demo cho giảng viên ($5)
Tuần 4: Tắt VM, giữ snapshot ($1)

→ Tổng: ~$16
→ Còn lại: $284
```

### Xem chi phí hiện tại

1. Truy cập: https://console.cloud.google.com/
2. Menu → **Billing** → **Reports**
3. Xem biểu đồ chi phí theo ngày/tháng

### Setup Budget Alerts

1. Menu → **Billing** → **Budgets & alerts**
2. Click **"Create budget"**
3. Set amount: **$300**
4. Set alerts: **50%, 90%, 100%**
5. Nhập email để nhận thông báo

---

## 📋 Checklist

### Trước khi demo

- [ ] VM đang chạy (`gcloud compute instances list`)
- [ ] Website accessible: `http://VM_IP/`
- [ ] API working: `http://VM_IP/api/hello`
- [ ] Keycloak accessible: `http://VM_IP/auth/`
- [ ] Grafana accessible: `http://VM_IP/grafana/`
- [ ] Đã test tất cả tính năng
- [ ] Đã lưu lại VM IP

### Trong demo

- [ ] Show website
- [ ] Show API response (load balancing)
- [ ] Show Keycloak login
- [ ] Show Grafana dashboard
- [ ] Show Docker containers: `docker ps`
- [ ] Show architecture diagram
- [ ] Giải thích kiến trúc 3-tier network

### Sau demo

- [ ] Tắt VM để tiết kiệm chi phí
- [ ] Hoặc xóa VM nếu đã hoàn thành đồ án
- [ ] Giữ snapshot làm bằng chứng

---

## 🎯 Tóm tắt

### Những gì bạn đã làm

1. ✅ Tạo tài khoản GCP với $300 credit
2. ✅ Cài đặt Google Cloud SDK
3. ✅ Tạo VM ở Singapore (delay thấp)
4. ✅ Deploy 17 containers lên VM
5. ✅ Truy cập website qua Internet

### Thông tin quan trọng

- **VM Name:** minicloud-demo
- **Zone:** asia-southeast1-a (Singapore)
- **VM IP:** [Lưu lại IP của bạn]
- **Chi phí:** ~$19/tháng hoặc $5 nếu tắt khi không dùng

### Lệnh quan trọng nhất

```bash
# Tắt VM (sau demo)
gcloud compute instances stop minicloud-demo --zone=asia-southeast1-a

# Bật VM (trước demo)
gcloud compute instances start minicloud-demo --zone=asia-southeast1-a

# SSH vào VM
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a

# Xóa VM (sau khi xong đồ án)
gcloud compute instances delete minicloud-demo --zone=asia-southeast1-a
```

---

## 📞 Hỗ trợ

### Tài liệu chính thức

- **GCP Free Tier:** https://cloud.google.com/free
- **Compute Engine Docs:** https://cloud.google.com/compute/docs
- **Pricing Calculator:** https://cloud.google.com/products/calculator

### Community

- **Stack Overflow:** https://stackoverflow.com/questions/tagged/google-cloud-platform
- **Reddit:** https://www.reddit.com/r/googlecloud/

---

**🎉 Chúc bạn demo thành công!**

**Có thắc mắc?** Đọc lại phần [Xử lý lỗi](#xử-lý-lỗi) hoặc search trên Google với từ khóa: "GCP [tên lỗi]"
