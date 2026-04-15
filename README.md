# Cloud Computing — Đồ án cuối kỳ

Dự án triển khai một hệ thống **MiniCloud** hoàn chỉnh trên Docker Compose, mô phỏng kiến trúc cloud thực tế với đầy đủ các lớp: web, API, xác thực, lưu trữ, DNS nội bộ, và giám sát.

---

## Thành viên nhóm

| MSSV | Họ tên | Vai trò |
|------|--------|---------|
| 52300232 | Trần Thanh Nhã | Cloud Infrastructure |
| 52300299 | Từ Thanh Ngôn | Frontend & UI/UX |
| 52300267 | Huỳnh Nguyễn Quốc Việt | Backend & DevOps |

---

## Tổng quan hệ thống

```
MiniCloud/
├── app/          # Flask API backend
├── auth/         # Keycloak (custom Dockerfile)
├── bind9/        # DNS nội bộ Bind9
├── db-init/      # SQL khởi tạo MariaDB
├── nginx/        # Nginx reverse proxy + load balancer
├── prometheus/   # Cấu hình scrape Prometheus
├── secrets/      # Docker Secrets (không commit)
├── web/          # Static web + blog cá nhân
└── docker-compose.yml
```

**14 container**, **3 mạng ảo**, **5 Prometheus scrape jobs**.

---

## Các tính năng đã triển khai

| # | Tính năng | Trạng thái |
|---|-----------|-----------|
| 1 | Web tĩnh + Blog cá nhân (3 bài: du lịch, công nghệ, ẩm thực) | ✅ |
| 2 | Flask API `/api/student` đọc từ MariaDB | ✅ |
| 3 | MariaDB `studentdb` với bảng `students` (CRUD) | ✅ |
| 4 | Keycloak OIDC — realm, client, `/api/student/secure` | ✅ |
| 5 | MinIO Object Storage — bucket, upload/download | ✅ |
| 6 | DNS Bind9 nội bộ + bản ghi `minio`, `keycloak`, `app-backend` | ✅ |
| 7 | Prometheus — 5 scrape jobs (prometheus, node-exporter, app, db, web) | ✅ |
| 8 | Grafana Dashboard — CPU, RAM, Network | ✅ |
| 9 | Nginx route `/student/` → backend API | ✅ |
| 10 | Load Balancer Round Robin — web1 + web2 | ✅ |

---

## Khởi động nhanh

**Yêu cầu:** Docker + Docker Compose, RAM ≥ 4 GB.

```bash
# 1. Tạo secrets (mỗi file 1 dòng)
mkdir MiniCloud/secrets
echo "your_db_root_pass"  > MiniCloud/secrets/db_root_password.txt
echo "your_db_pass"       > MiniCloud/secrets/db_password.txt
echo "your_kc_admin_pass" > MiniCloud/secrets/kc_admin_password.txt
echo "admin"              > MiniCloud/secrets/storage_root_user.txt
echo "your_minio_pass"    > MiniCloud/secrets/storage_root_pass.txt

# 2. Build & chạy
cd MiniCloud
docker compose up -d --build

# 3. Kiểm tra
docker compose ps
```

---

## Truy cập

| Dịch vụ | URL | Ghi chú |
|---------|-----|---------|
| Website | `http://localhost:8088/` | Round-robin web1/web2 |
| API sinh viên | `http://localhost:8088/api/student` | JSON từ MariaDB |
| Keycloak | `http://localhost:8088/auth/` | Realm: `realm_52300267` |
| Grafana | `http://localhost:3000/` | `admin` / `admin` |
| Prometheus | `http://localhost:9090/` | Chỉ localhost |
| MinIO Console | `http://localhost:9001/` | Object storage |

---

---

## ☁️ Deploy lên Google Cloud Platform

### 📖 Hướng dẫn chi tiết từ đầu đến cuối

**→ Đọc file: [HUONG_DAN_DEPLOY_GCP.md](./HUONG_DAN_DEPLOY_GCP.md)**

Hướng dẫn đầy đủ cho người mới, bao gồm:
- ✅ Tạo tài khoản GCP (nhận $300 credit)
- ✅ Cài đặt Google Cloud SDK
- ✅ Tạo VM ở Singapore (delay thấp ~20ms)
- ✅ Deploy 17 containers
- ✅ Quản lý VM và xử lý lỗi

**Thời gian:** 45-60 phút  
**Chi phí:** MIỄN PHÍ 15 tháng với $300 credit

---

## Tài liệu chi tiết

### Local Development
- [`MiniCloud/README.md`](MiniCloud/README.md) — Kiến trúc đầy đủ, cấu hình port, bảo mật
- [`MiniCloud/KIEM_TRA_HE_THONG.md`](MiniCloud/KIEM_TRA_HE_THONG.md) — Hướng dẫn kiểm tra từng service
- [`MiniCloud/TEAM_ASSIGNMENT.md`](MiniCloud/TEAM_ASSIGNMENT.md) — Phân công nhiệm vụ nhóm

### Cloud Deployment
- [`GCP_QUICKSTART.md`](./GCP_QUICKSTART.md) — Deploy GCP trong 30 phút ⭐
- [`GCP_DEPLOYMENT_GUIDE.md`](./GCP_DEPLOYMENT_GUIDE.md) — Hướng dẫn GCP chi tiết
- [`AWS_DEPLOYMENT_TIMELINE.md`](./AWS_DEPLOYMENT_TIMELINE.md) — Timeline deploy AWS
- [`CLOUD_DEPLOYMENT_COMPARISON.md`](./CLOUD_DEPLOYMENT_COMPARISON.md) — So sánh GCP vs AWS vs Azure

### Scripts
- [`MiniCloud/deploy-gcp.sh`](./MiniCloud/deploy-gcp.sh) — Script deploy tự động lên GCP
- [`MiniCloud/gcp-cost-optimizer.sh`](./MiniCloud/gcp-cost-optimizer.sh) — Tối ưu chi phí GCP
