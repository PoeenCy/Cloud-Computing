# MiniCloud - Tóm tắt Kiến trúc Hệ thống

## 📊 Tổng quan

MiniCloud là hệ thống microservices với **17 containers** chạy trên **3 mạng ảo** được phân vùng theo Best Practice về Security và Observability.

## 🏗️ Kiến trúc 3 lớp (Micro-segmentation)

### 1. Frontend Network (10.10.1.0/24)
**Vai trò:** Lớp tiếp xúc người dùng và xử lý HTTP requests

| Container | IP | Port | Mô tả |
|-----------|----|----|-------|
| Nginx Proxy | 10.10.1.10 | 80/443 | **Gateway duy nhất** - Exposed port 8088 |
| Web Server 1 | 10.10.1.11 | 80 | Static content (Round-robin) |
| Web Server 2 | 10.10.1.20 | 80 | Static content (Round-robin) |
| App Flask 1 | 10.10.1.12 | 8081 | API Backend (Round-robin) |
| App Flask 2 | 10.10.1.22 | 8081 | API Backend (Round-robin) - **HA** |
| Keycloak | 10.10.1.13 | 8080 | Identity & Access Management |
| nginx-exporter | 10.10.1.21 | 9113 | Nginx metrics exporter |
| Prometheus (FE) | 10.10.1.16 | 9090 | Cross-subnet scraping |

**Đặc điểm:**
- ✅ Round-robin load balancing cho Web và API
- ✅ High Availability với 2 Flask instances
- ✅ Tất cả traffic qua Nginx Proxy (port 8088)

### 2. Backend Network (10.10.2.0/24 - Internal)
**Vai trò:** Lớp dữ liệu - **Hoàn toàn cô lập khỏi Internet**

| Container | IP | Port | Mô tả |
|-----------|----|----|-------|
| MariaDB | 10.10.2.14 | 3306 | Relational Database |
| MinIO | 10.10.2.15 | 9000/9001 | Object Storage (S3 API + Console) |
| Redis | 10.10.2.16 | 6379 | Cache & Session Store |
| mysqld-exporter | 10.10.2.20 | 9104 | MariaDB metrics exporter |
| Prometheus (BE) | 10.10.2.21 | 9090 | Cross-subnet scraping |

**Đặc điểm:**
- 🔒 `internal: true` - Không có route ra Internet
- 🔒 MinIO **chỉ** nằm trong backend (không expose ra frontend)
- 🔒 Chỉ App Flask và Keycloak có quyền truy cập

### 3. Management Network (10.10.3.0/24)
**Vai trò:** Lớp vận hành - Monitoring, Logging, DNS

| Container | IP | Port | Mô tả |
|-----------|----|----|-------|
| DNS Bind9 | 10.10.3.53 | 53 | Internal DNS resolver |
| Prometheus | 10.10.3.16 | 9090 | **Primary** metrics collector |
| Loki | 10.10.3.17 | 3100 | Log aggregation |
| Grafana | 10.10.3.18 | 3000 | Observability dashboard |
| Node Exporter | 10.10.3.19 | 9100 | Host metrics |
| nginx-exporter | 10.10.3.21 | 9113 | Nginx metrics |
| Promtail | 10.10.3.22 | 9080 | Log collector agent |

**Đặc điểm:**
- 📊 Prometheus có 3 IPs để scrape từ cả 3 subnets
- 📊 Promtail gom logs từ Docker containers
- 📊 Grafana tổng hợp metrics + logs

## 🔐 Bảo mật (Security Best Practices)

### 1. Network Segmentation
```
Frontend (10.10.1.x)  ←→  Backend (10.10.2.x - Internal)
        ↓                         ↓
    Management (10.10.3.x)
```

- Backend network **không có Internet access**
- Chỉ services cần thiết mới được gắn nhiều networks
- Prometheus có 3 IPs để scrape cross-subnet

### 2. Single Entry Point
- **Chỉ có Nginx Proxy** expose port ra host (8088)
- Tất cả services khác chỉ accessible qua proxy
- Auth protection cho Prometheus và MinIO Console

### 3. Docker Secrets
Tất cả credentials được quản lý bằng Docker Secrets:
- `db_password` - MariaDB user password
- `db_root_password` - MariaDB root password
- `kc_admin_password` - Keycloak admin password
- `storage_root_user` / `storage_root_pass` - MinIO credentials

### 4. Authentication & Authorization
- Keycloak: OAuth2/OIDC provider
- Nginx `auth_request`: Bảo vệ Prometheus và MinIO
- Cookie-based authentication (`mc_token`)

## 📈 Observability Stack

### Metrics Collection (Prometheus)
```
Prometheus (10.10.3.16) scrapes:
├── Node Exporter (10.10.3.19:9100) - Host metrics
├── App Flask 1 (10.10.1.12:8081) - App metrics
├── App Flask 2 (10.10.1.22:8081) - App metrics
├── mysqld-exporter (10.10.2.20:9104) - DB metrics
├── nginx-exporter (10.10.3.21:9113) - Nginx metrics
└── Self (10.10.3.16:9090) - Prometheus metrics
```

**Tất cả targets: UP ✅**

### Log Collection (Loki + Promtail)
```
Docker Containers → Promtail (10.10.3.22) → Loki (10.10.3.17)
                                                    ↓
                                            Grafana (10.10.3.18)
```

Promtail gom logs từ:
- Nginx Proxy
- Web Servers (1 & 2)
- App Flask (1 & 2)
- MariaDB
- Keycloak

### Visualization (Grafana)
- URL: `http://localhost:8088/grafana/`
- Data sources: Prometheus + Loki
- Unified dashboard cho metrics và logs

## 🚀 High Availability

### Load Balancing
1. **Web Tier:** 2 instances (web1, web2) - Round-robin
2. **API Tier:** 2 instances (app1, app2) - Round-robin

### Upstream Configuration (Nginx)
```nginx
upstream web_pool {
    server 10.10.1.11:80;  # web1
    server 10.10.1.20:80;  # web2
}

upstream app_pool {
    server 10.10.1.12:8081;  # app1
    server 10.10.1.22:8081;  # app2
}
```

## 🌐 Routing Table

| Path | Backend | Load Balancing | Auth Required |
|------|---------|----------------|---------------|
| `/` | web_pool | Round-robin | ❌ Public |
| `/api/` | app_pool | Round-robin | ❌ Public |
| `/student/` | app_pool | Round-robin | ❌ Public |
| `/auth/` | Keycloak | - | ❌ Public (Keycloak manages) |
| `/grafana/` | Grafana (10.10.3.18) | - | ⚠️ Grafana manages |
| `/prometheus/` | Prometheus (10.10.3.16) | - | ✅ Cookie `mc_token` |
| `/minio/` | MinIO (10.10.2.15:9001) | - | ✅ Cookie `mc_token` |

## 📝 DNS Resolution

Internal DNS (Bind9) resolves `*.cloud.local`:

| Hostname | IP | Service |
|----------|----|----|
| `proxy.cloud.local` | 10.10.1.10 | Nginx Proxy |
| `web1.cloud.local` | 10.10.1.11 | Web Server 1 |
| `web2.cloud.local` | 10.10.1.20 | Web Server 2 |
| `app.cloud.local` | 10.10.1.12 | App Flask 1 |
| `auth.cloud.local` | 10.10.1.13 | Keycloak |
| `db.cloud.local` | 10.10.2.14 | MariaDB |
| `storage.cloud.local` | 10.10.2.15 | MinIO |
| `monitoring.cloud.local` | 10.10.3.16 | Prometheus |
| `grafana.cloud.local` | 10.10.3.18 | Grafana |
| `dns.cloud.local` | 10.10.3.53 | Bind9 |

## ✅ Verification Checklist

### 1. Containers Status
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```
**Expected:** All containers `Up` and `healthy`

### 2. Network Connectivity
```bash
# Frontend
curl -I http://localhost:8088/
curl http://localhost:8088/api/hello

# Prometheus targets
docker exec minicloud-monitoring wget -qO- \
  "http://localhost:9090/prometheus/api/v1/targets" | \
  jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"'
```
**Expected:** All targets `up`

### 3. Services Access
- Website: http://localhost:8088/
- API: http://localhost:8088/api/hello
- Keycloak: http://localhost:8088/auth/
- Grafana: http://localhost:8088/grafana/
- Prometheus: http://localhost:8088/prometheus/ (requires login)
- MinIO: http://localhost:8088/minio/ (requires login)

## 🎯 Key Achievements

✅ **Security:**
- Backend network hoàn toàn isolated
- Single entry point (Nginx Proxy)
- MinIO không expose ra frontend
- Docker Secrets cho credentials

✅ **High Availability:**
- 2 Web instances với load balancing
- 2 API instances với load balancing
- Healthchecks cho tất cả services

✅ **Observability:**
- Prometheus scrape 6 targets (all UP)
- Loki + Promtail cho log aggregation
- Grafana unified dashboard
- Cross-subnet monitoring

✅ **Best Practices:**
- Micro-segmentation (3 networks)
- Internal DNS resolution
- Proper healthchecks
- Dependency management (depends_on)

---

**Tổng số containers:** 17  
**Tổng số networks:** 3  
**Exposed ports:** 8088 (HTTP), 443 (HTTPS), 53 (DNS)  
**Architecture:** Microservices with 3-tier network segmentation
