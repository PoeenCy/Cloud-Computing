# 🔧 Sửa lỗi Dashboards không có data

## 📊 Tóm tắt vấn đề

| Dashboard | Status | Vấn đề |
|-----------|--------|--------|
| **MySQL/MariaDB** | ❌ Không có data | mysqld-exporter không kết nối được DB (password không đọc được) |
| **Flask** | ✅ Có data | Hoạt động bình thường |
| **Redis** | ❌ Không có data | Chưa có redis-exporter |

---

## 1. Sửa MySQL/MariaDB Dashboard

### Vấn đề
```
Error: Access denied for user 'admin'@'10.10.2.20' (using password: NO)
```

mysqld-exporter không đọc được password từ secret file.

### Giải pháp

Mở file `MiniCloud/docker-compose.yml`, tìm section `mysqld-exporter:` (khoảng dòng 389), thay thế bằng:

```yaml
  mysqld-exporter:
    image: prom/mysqld-exporter:latest
    container_name: minicloud-mysqld-exporter
    networks:
      backend-net:
        ipv4_address: 10.10.2.20
    dns:
      - 10.10.3.53
    secrets:
      - db_password
    entrypoint:
      - /bin/sh
      - -c
      - |
        DB_PASS=$(cat /run/secrets/db_password)
        echo "[client]" > /tmp/.my.cnf
        echo "user=admin" >> /tmp/.my.cnf
        echo "password=$DB_PASS" >> /tmp/.my.cnf
        echo "host=minicloud-db" >> /tmp/.my.cnf
        echo "port=3306" >> /tmp/.my.cnf
        exec /bin/mysqld_exporter --config.my-cnf=/tmp/.my.cnf
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:9104/metrics || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Restart container

```powershell
cd MiniCloud
docker compose restart mysqld-exporter
```

### Kiểm tra

```powershell
# Xem logs
docker logs minicloud-mysqld-exporter --tail 20

# Kiểm tra metrics
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/prometheus/api/v1/query?query=mysql_up"
```

Phải thấy: `mysql_up = 1`

---

## 2. Flask Dashboard - Đã hoạt động ✅

Flask metrics đã có sẵn trong Prometheus:
- `flask_http_request_total`
- `flask_http_request_duration_seconds`
- `process_cpu_seconds_total`
- `process_resident_memory_bytes`

### Import Dashboard

```
Grafana → Import → ID: 3662
Prometheus: Chọn "Prometheus"
Import
```

### Hoặc tạo dashboard custom

**Query ví dụ**:

```promql
# Request rate
rate(flask_http_request_total[5m])

# Request duration
flask_http_request_duration_seconds_sum / flask_http_request_duration_seconds_count

# CPU usage
rate(process_cpu_seconds_total{job="app"}[5m])

# Memory usage
process_resident_memory_bytes{job="app"}
```

---

## 3. Redis Dashboard - Cần thêm exporter

### Vấn đề

Redis đang chạy nhưng **không có exporter** → Không có metrics trong Prometheus.

### Giải pháp: Thêm redis-exporter

Thêm vào `docker-compose.yml` (sau section `redis:`):

```yaml
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: minicloud-redis-exporter
    networks:
      backend-net:
        ipv4_address: 10.10.2.17
      mgmt-net:
        ipv4_address: 10.10.3.25
    dns:
      - 10.10.3.53
    environment:
      REDIS_ADDR: "minicloud-redis:6379"
      REDIS_PASSWORD: "${REDIS_PASSWORD:-redis_secret_123}"
    restart: unless-stopped
    depends_on:
      - redis
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:9121/metrics || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Thêm vào Prometheus config

Mở `MiniCloud/prometheus/prometheus.yml`, thêm job:

```yaml
  # Redis Exporter
  - job_name: 'redis'
    static_configs:
      - targets: ['10.10.2.17:9121']
```

### Khởi động

```powershell
cd MiniCloud
docker compose up -d redis-exporter
docker compose restart monitoring
```

### Kiểm tra

```powershell
# Xem logs
docker logs minicloud-redis-exporter --tail 20

# Kiểm tra metrics
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/prometheus/api/v1/query?query=redis_up"
```

Phải thấy: `redis_up = 1`

### Import Dashboard

```
Grafana → Import → ID: 11835
Prometheus: Chọn "Prometheus"
Import
```

---

## 📋 Checklist

### MySQL/MariaDB
- [ ] Sửa mysqld-exporter config
- [ ] Restart container
- [ ] Kiểm tra `mysql_up = 1`
- [ ] Import dashboard ID: 7362

### Flask
- [ ] Kiểm tra metrics có sẵn
- [ ] Import dashboard ID: 3662
- [ ] Hoặc tạo custom dashboard

### Redis
- [ ] Thêm redis-exporter vào docker-compose.yml
- [ ] Thêm job vào prometheus.yml
- [ ] Khởi động redis-exporter
- [ ] Restart Prometheus
- [ ] Kiểm tra `redis_up = 1`
- [ ] Import dashboard ID: 11835

---

## 🎯 Kết quả mong đợi

Sau khi hoàn thành:

**Prometheus Targets** (9 targets UP):
- ✅ prometheus
- ✅ node-exporter
- ✅ app (app1, app2)
- ✅ db (mysqld-exporter)
- ✅ nginx-exporter (web1, web2)
- ✅ redis (redis-exporter) ← Mới

**Grafana Dashboards**:
- ✅ Node Exporter Full (ID: 1860)
- ✅ Nginx Exporter (ID: 12708)
- ✅ MySQL Overview (ID: 7362)
- ✅ Flask Exporter (ID: 3662)
- ✅ Redis Dashboard (ID: 11835)

---

**Good luck! 📊✨**
