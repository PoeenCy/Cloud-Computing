# 📊 MiniCloud Custom Dashboards

## ✅ Dashboards đã tối ưu cho MiniCloud

Thư mục này chứa các dashboards đã được tạo sẵn với queries phù hợp với cấu hình Prometheus của MiniCloud.

**Ưu điểm:**
- ✅ Không cần sửa variables
- ✅ Queries đã match với job names và instance labels
- ✅ Import và dùng ngay, có data luôn
- ✅ Đơn giản, dễ hiểu, dễ customize

---

## 📋 Danh sách Dashboards

### 1. `mysql-simple.json` - MySQL/MariaDB Dashboard
**Panels:**
- MySQL Status (UP/DOWN)
- MySQL Uptime
- Queries per Second
- Active Connections (Connected vs Running)
- Commands breakdown (SELECT, INSERT, UPDATE, DELETE, etc.)

**Metrics:**
- `mysql_up` - Database status
- `mysql_global_status_uptime` - Uptime
- `mysql_global_status_queries` - Total queries
- `mysql_global_status_threads_connected` - Connections
- `mysql_global_status_commands_total` - Commands by type

### 2. `web-simple.json` - Web Servers Dashboard
**Panels:**
- Web1 Status (UP/DOWN)
- Web2 Status (UP/DOWN)
- Active Connections (web1 + web2)
- Requests per Second
- Connection States (Reading, Writing, Waiting)
- Total Connections Accepted

**Metrics:**
- `nginx_up` - Server status
- `nginx_connections_active` - Active connections
- `nginx_connections_accepted` - Total accepted
- `nginx_connections_reading/writing/waiting` - Connection states

---

## 🚀 Cách Import Dashboards

### Bước 1: Truy cập Grafana
```
http://localhost:8088/grafana/
```
Login: `admin` / `admin`

### Bước 2: Import Dashboard
1. Click vào menu **☰** (góc trên bên trái)
2. Chọn **Dashboards**
3. Click nút **New** → **Import**
4. Click **Upload JSON file**
5. Chọn file:
   - `mysql-simple.json` cho MySQL dashboard
   - `web-simple.json` cho Web Servers dashboard
6. Click **Import**

**Hoặc copy-paste:**
1. Mở file JSON bằng text editor
2. Copy toàn bộ nội dung
3. Paste vào ô "Import via panel json" trong Grafana
4. Click **Load** → **Import**

### Bước 3: Xem Dashboard
Dashboard sẽ hiển thị dữ liệu ngay lập tức!
- Auto-refresh: 5 giây
- Time range: Last 15 minutes (có thể đổi)

---

## 🎨 Customize Dashboards

### Thêm Panels
1. Click **Add** → **Visualization**
2. Chọn **Prometheus** datasource
3. Nhập query, ví dụ:
   ```promql
   mysql_global_status_slow_queries{job="mysql"}
   ```
4. Chọn visualization type (Time series, Stat, Gauge, etc.)
5. Click **Apply**

### Sửa Panels
1. Click vào panel title
2. Chọn **Edit**
3. Sửa query, title, visualization settings
4. Click **Apply**

### Thêm Variables (Advanced)
1. Dashboard settings (⚙️) → **Variables**
2. **Add variable**
3. Ví dụ tạo variable cho instance:
   - Name: `instance`
   - Type: `Query`
   - Query: `label_values(mysql_up{job="mysql"}, instance)`
4. Dùng trong query: `mysql_up{instance="$instance"}`

---

## 📊 Queries Hữu Ích

### MySQL Queries
```promql
# Database size (nếu có exporter config)
mysql_global_status_innodb_data_written

# Slow queries
mysql_global_status_slow_queries{job="mysql"}

# Table locks
mysql_global_status_table_locks_waited{job="mysql"}

# InnoDB buffer pool usage
mysql_global_status_innodb_buffer_pool_pages_total{job="mysql"}
```

### NGINX Queries
```promql
# Total requests
nginx_connections_accepted{job="web"}

# Request rate
rate(nginx_connections_accepted{job="web"}[5m])

# Active connections per instance
nginx_connections_active{job="web", instance="web1"}

# Connection states
nginx_connections_reading{job="web"}
nginx_connections_writing{job="web"}
nginx_connections_waiting{job="web"}
```

### Redis Queries (nếu cần tạo dashboard)
```promql
# Redis status
redis_up{job="redis"}

# Memory usage
redis_memory_used_bytes{job="redis"}

# Connected clients
redis_connected_clients{job="redis"}

# Commands per second
rate(redis_commands_processed_total{job="redis"}[5m])

# Hit rate
rate(redis_keyspace_hits_total{job="redis"}[5m]) / 
(rate(redis_keyspace_hits_total{job="redis"}[5m]) + 
 rate(redis_keyspace_misses_total{job="redis"}[5m]))
```

### Flask Queries (nếu cần tạo dashboard)
```promql
# HTTP requests
flask_http_request_total{job="app"}

# Request rate
rate(flask_http_request_total{job="app"}[5m])

# Request duration
flask_http_request_duration_seconds_sum{job="app"} / 
flask_http_request_duration_seconds_count{job="app"}

# Requests by status code
flask_http_request_total{job="app", status="200"}
flask_http_request_total{job="app", status="500"}
```

---

## 🔧 Troubleshooting

### Dashboard hiển thị "No data"
1. **Kiểm tra Prometheus targets:**
   ```bash
   docker exec minicloud-monitoring wget -qO- http://localhost:9090/prometheus/targets
   ```
   Tất cả targets phải UP

2. **Test query trong Grafana Explore:**
   - Click **Explore** (🧭)
   - Chọn **Prometheus**
   - Test query: `mysql_up{job="mysql"}`

3. **Kiểm tra datasource:**
   - Settings (⚙️) → **Data sources**
   - Click **Prometheus**
   - Click **Save & test** - phải thấy "Data source is working"

### Datasource không tìm thấy
Khi import, nếu báo lỗi datasource:
1. Chọn **Prometheus** từ dropdown
2. Hoặc vào Settings → Data sources → Add Prometheus:
   - URL: `http://minicloud-monitoring:9090/prometheus`
   - Click **Save & test**

---

## 📚 Tài liệu tham khảo

- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [MySQL Exporter Metrics](https://github.com/prometheus/mysqld_exporter)
- [NGINX Exporter Metrics](https://github.com/nginxinc/nginx-prometheus-exporter)

---

## 🎉 Kết luận

Các dashboards này được thiết kế đơn giản để bạn có thể:
1. **Import và dùng ngay** - Không cần config gì thêm
2. **Hiểu được queries** - Dễ dàng customize
3. **Mở rộng** - Thêm panels mới theo nhu cầu

**Happy monitoring! 🚀**
