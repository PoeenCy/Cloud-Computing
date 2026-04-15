# Changelog - Kiến trúc MiniCloud v2.0

## 🎯 Mục tiêu
Tái cấu trúc hệ thống MiniCloud theo Best Practice về Security và Observability với phân vùng mạng rõ ràng và High Availability.

## 📋 Các thay đổi chính

### 1. Network Segmentation (Phân vùng mạng)

#### Frontend Network (10.10.1.0/24)
**Trước:**
- Proxy, Web1/2, App, Keycloak, Prometheus, MinIO (UI), Grafana

**Sau:**
- Proxy, Web1/2, **App1**, **App2** (mới), Keycloak, nginx-exporter
- ✅ Loại bỏ MinIO khỏi frontend
- ✅ Loại bỏ Grafana khỏi frontend
- ✅ Thêm App Flask 2 cho HA

#### Backend Network (10.10.2.0/24 - Internal)
**Trước:**
- MariaDB, MinIO (API), mysqld-exporter

**Sau:**
- MariaDB, **MinIO (cả UI + API)**, Redis, mysqld-exporter
- ✅ Di chuyển MinIO hoàn toàn về backend (10.10.2.15)
- ✅ Loại bỏ mgmt-net khỏi mysqld-exporter
- ✅ Loại bỏ mgmt-net khỏi Redis

#### Management Network (10.10.3.0/24)
**Trước:**
- DNS, Loki, Grafana, Node Exporter, nginx-exporter, Redis

**Sau:**
- DNS, **Prometheus** (primary), Loki, Grafana, Node Exporter, nginx-exporter, **Promtail** (mới)
- ✅ Di chuyển Prometheus từ frontend sang mgmt (10.10.3.16)
- ✅ Di chuyển Grafana chỉ nằm trong mgmt (10.10.3.18)
- ✅ Thêm Promtail cho log aggregation

### 2. High Availability

#### Load Balancing
**Mới thêm:**
```nginx
upstream app_pool {
    server 10.10.1.12:8081;  # app1
    server 10.10.1.22:8081;  # app2
}
```

**Kết quả:**
- ✅ 2 Web instances (web1, web2) - Round-robin
- ✅ 2 API instances (app1, app2) - Round-robin
- ✅ Tự động failover nếu một instance down

### 3. Security Improvements

#### MinIO Isolation
**Trước:** MinIO có 3 IPs (frontend, backend, mgmt)
```yaml
networks:
  frontend-net: 10.10.1.15
  backend-net: 10.10.2.15
  mgmt-net: 10.10.3.15
```

**Sau:** MinIO chỉ nằm trong backend
```yaml
networks:
  backend-net: 10.10.2.15  # Only backend
```

**Nginx routing:**
```nginx
location /minio/ {
    auth_request /_auth_check;
    proxy_pass http://10.10.2.15:9001;  # Backend IP
}
```

#### Prometheus Cross-Subnet Access
**Sau:** Prometheus có 3 IPs để scrape từ mọi subnet
```yaml
networks:
  mgmt-net: 10.10.3.16      # Primary
  backend-net: 10.10.2.21   # Scrape backend
  frontend-net: 10.10.1.16  # Scrape frontend
```

### 4. Observability Enhancements

#### Prometheus Targets
**Trước:** 6 targets
- prometheus, node-exporter, app, db, web (2 targets), nginx-exporter

**Sau:** 6 targets (optimized)
- prometheus, node-exporter, **app (2 instances)**, db, nginx-exporter
- ✅ Loại bỏ direct web scraping (nginx-exporter handles it)
- ✅ Thêm app2 target
- ✅ Sửa prometheus self-scraping với route prefix

#### Log Aggregation
**Mới thêm:**
```
Docker Containers → Promtail → Loki → Grafana
```

**Promtail scrapes logs từ:**
- Nginx Proxy
- Web Servers (1 & 2)
- App Flask (1 & 2)
- MariaDB
- Keycloak

### 5. Routing Updates

#### Nginx Proxy
**Thay đổi:**
```nginx
# Trước
location /api/ {
    proxy_pass http://10.10.1.12:8081;  # Single instance
}

# Sau
location /api/ {
    proxy_pass http://app_pool;  # Load balanced
}
```

**Auth check:**
```nginx
# Trước
location = /_auth_check {
    proxy_pass http://10.10.1.12:8081/api/auth/me-cookie;
}

# Sau
location = /_auth_check {
    proxy_pass http://app_pool/api/auth/me-cookie;  # Load balanced
}
```

**Service endpoints:**
```nginx
# Grafana: frontend → mgmt
location /grafana/ {
    proxy_pass http://10.10.3.18:3000;  # Was 10.10.1.18
}

# Prometheus: frontend → mgmt
location /prometheus/ {
    proxy_pass http://10.10.3.16:9090;  # Was 10.10.1.16
}

# MinIO: frontend → backend
location /minio/ {
    proxy_pass http://10.10.2.15:9001;  # Was 10.10.1.15
}
```

### 6. Configuration Files

#### docker-compose.yml
- ✅ Thêm service `app2` (App Flask 2)
- ✅ Thêm service `promtail` (Log collector)
- ✅ Cập nhật networks cho tất cả services
- ✅ Sửa healthcheck cho Prometheus (route prefix)
- ✅ Loại bỏ healthcheck cho Promtail (minimal image)

#### nginx.conf
- ✅ Thêm `upstream app_pool`
- ✅ Cập nhật tất cả proxy_pass với IPs mới
- ✅ Sử dụng app_pool cho load balancing

#### prometheus.yml
- ✅ Thêm app2 target (10.10.1.22:8081)
- ✅ Sửa self-scraping target (10.10.3.16:9090)
- ✅ Thêm metrics_path cho prometheus job
- ✅ Loại bỏ web job (nginx-exporter handles it)

#### promtail/config.yml (Mới)
- ✅ Cấu hình Docker SD
- ✅ Static configs cho các services chính
- ✅ Forward logs về Loki

## 📊 Kết quả

### Containers
**Trước:** 15 containers  
**Sau:** 17 containers (+2: app2, promtail)

### Networks
**Không đổi:** 3 networks (frontend, backend, mgmt)  
**Cải thiện:** Phân vùng rõ ràng hơn

### Exposed Ports
**Không đổi:** 8088 (HTTP), 443 (HTTPS), 53 (DNS)

### Prometheus Targets
**Trước:** 6 targets (1 down)  
**Sau:** 6 targets (all UP ✅)

### Load Balancing
**Trước:** Chỉ Web tier  
**Sau:** Web tier + API tier

## ✅ Verification

### All Containers Healthy
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```
✅ 17/17 containers running  
✅ 16/17 healthy (promtail không có healthcheck)

### All Prometheus Targets UP
```bash
docker exec minicloud-monitoring wget -qO- \
  "http://localhost:9090/prometheus/api/v1/targets"
```
✅ app (instance=app1) - up  
✅ app (instance=app2) - up  
✅ db - up  
✅ nginx-exporter - up  
✅ node-exporter - up  
✅ prometheus - up

### Services Accessible
✅ Website: http://localhost:8088/  
✅ API: http://localhost:8088/api/hello  
✅ Keycloak: http://localhost:8088/auth/  
✅ Grafana: http://localhost:8088/grafana/  
✅ Prometheus: http://localhost:8088/prometheus/ (auth required)  
✅ MinIO: http://localhost:8088/minio/ (auth required)

## 🎓 Best Practices Implemented

### Security
✅ Network micro-segmentation (3 tiers)  
✅ Backend network isolation (internal: true)  
✅ Single entry point (Nginx Proxy)  
✅ MinIO không expose ra frontend  
✅ Docker Secrets cho credentials  
✅ Auth protection cho sensitive endpoints

### High Availability
✅ Load balancing cho Web tier  
✅ Load balancing cho API tier  
✅ Healthchecks cho tất cả services  
✅ Proper dependency management

### Observability
✅ Prometheus cross-subnet monitoring  
✅ Log aggregation với Loki + Promtail  
✅ Unified dashboard với Grafana  
✅ Metrics từ 6 targets  
✅ Logs từ 5+ containers

### Operations
✅ Internal DNS resolution  
✅ Proper startup order  
✅ Graceful degradation  
✅ Easy troubleshooting

## 📚 Documentation

- ✅ README.md - Cập nhật với kiến trúc mới
- ✅ ARCHITECTURE_SUMMARY.md - Tóm tắt chi tiết
- ✅ CHANGELOG.md - Lịch sử thay đổi (file này)
- ✅ Mermaid diagram - Sơ đồ kiến trúc mới

---

**Version:** 2.0  
**Date:** April 15, 2026  
**Status:** ✅ Production Ready
