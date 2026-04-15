# ✅ Đã sửa Labels cho Dashboards

## 🔧 Vấn đề đã fix

**Vấn đề**: Dashboards không hiển thị dữ liệu vì Prometheus labels không khớp với dashboard queries.

**Giải pháp**: Đã cập nhật `prometheus.yml` để thêm labels chuẩn cho tất cả exporters.

---

## 📊 Cấu hình mới

### 1. MySQL/MariaDB
```yaml
- job_name: 'mysql'
  static_configs:
    - targets: ['10.10.2.20:9104']
      labels:
        instance: 'minicloud-db'
        server: 'mariadb'
```
**Metrics**: `mysql_up{instance="minicloud-db", job="mysql"}`

### 2. Redis
```yaml
- job_name: 'redis'
  static_configs:
    - targets: ['10.10.2.17:9121']
      labels:
        instance: 'minicloud-redis'
        server: 'redis'
```
**Metrics**: `redis_up{instance="minicloud-redis", job="redis"}`

### 3. NGINX
```yaml
- job_name: 'nginx'
  static_configs:
    - targets: ['10.10.3.21:9113']
      labels:
        instance: 'web1'
        server: 'nginx'
    - targets: ['10.10.3.23:9113']
      labels:
        instance: 'web2'
        server: 'nginx'
```
**Metrics**: `nginx_connections_active{instance="web1", job="nginx"}`

---

## 🎯 Kết quả

### Prometheus Targets (8/8 UP)
| Job | Instance | Status |
|-----|----------|--------|
| prometheus | 10.10.3.16:9090 | ✅ UP |
| node-exporter | monitoring-node-exporter-server | ✅ UP |
| app | app1 | ✅ UP |
| app | app2 | ✅ UP |
| **mysql** | **minicloud-db** | ✅ UP |
| **nginx** | **web1** | ✅ UP |
| **nginx** | **web2** | ✅ UP |
| **redis** | **minicloud-redis** | ✅ UP |

---

## 📈 Import Dashboards - Bây giờ sẽ có dữ liệu!

### 1. MySQL/MariaDB Dashboard (ID: 7362)
- Vào Grafana: `http://localhost:8088/grafana/`
- Import dashboard ID: **7362**
- Chọn Datasource: **Prometheus**
- **Lưu ý**: Sau khi import, nếu một số panels vẫn "No data":
  - Click vào panel title → Edit
  - Tìm query có `job="mysql"` hoặc `instance=~".*"`
  - Đảm bảo query filter đúng: `{job="mysql"}` hoặc `{instance="minicloud-db"}`

### 2. Redis Dashboard (ID: 11835)
- Import dashboard ID: **11835**
- Chọn Datasource: **Prometheus**
- Dashboard sẽ tự động detect instance: `minicloud-redis`

### 3. NGINX Dashboard (ID: 12708)
- Import dashboard ID: **12708**
- Chọn Datasource: **Prometheus**
- Dashboard sẽ hiển thị cả web1 và web2
- Có thể filter theo instance: `web1` hoặc `web2`

### 4. Flask Dashboard (ID: 3662)
- Import dashboard ID: **3662**
- Chọn Datasource: **Prometheus**
- Dashboard sẽ hiển thị metrics từ app1 và app2

### 5. Node Exporter Full (ID: 1860)
- Import dashboard ID: **1860**
- Chọn Datasource: **Prometheus**
- Dashboard sẽ hiển thị CPU, RAM, Disk, Network của host

---

## 🔍 Test Queries trong Grafana

Sau khi import, bạn có thể test các queries này trong Grafana Explore:

```promql
# MySQL
mysql_up{job="mysql"}
mysql_global_status_connections{job="mysql"}
mysql_global_status_queries{job="mysql"}

# Redis
redis_up{job="redis"}
redis_memory_used_bytes{job="redis"}
redis_connected_clients{job="redis"}

# NGINX
nginx_connections_active{job="nginx"}
nginx_connections_accepted{job="nginx"}

# Flask
flask_http_request_total{job="app"}
flask_http_request_duration_seconds_sum{job="app"}

# Node
node_cpu_seconds_total{job="node-exporter"}
node_memory_MemAvailable_bytes{job="node-exporter"}
```

---

## ⚠️ Lưu ý quan trọng

### 1. Old metrics sẽ tự động expire
Bạn có thể thấy duplicate metrics trong 5 phút đầu:
- `mysql_up{job="db"}` (cũ - sẽ biến mất)
- `mysql_up{job="mysql"}` (mới - sử dụng cái này)

Sau 5 phút, chỉ còn metrics mới.

### 2. Dashboard variables
Một số dashboards có variables (dropdown) để chọn instance:
- **MySQL Dashboard**: Chọn `minicloud-db`
- **Redis Dashboard**: Chọn `minicloud-redis`
- **NGINX Dashboard**: Chọn `web1` hoặc `web2` (hoặc All)

### 3. Customize queries
Nếu dashboard panel vẫn "No data", click Edit và sửa query:
- Thay `job="mysqld-exporter"` → `job="mysql"`
- Thay `job="redis-exporter"` → `job="redis"`
- Thay `job="nginx-exporter"` → `job="nginx"`

---

## 🎉 Hoàn tất!

**Bây giờ tất cả dashboards sẽ có dữ liệu!**

Nếu vẫn còn panels "No data":
1. Kiểm tra dashboard variables (dropdowns ở trên cùng)
2. Chọn đúng instance từ dropdown
3. Hoặc edit query để match với labels mới

**Enjoy your monitoring! 🚀**
