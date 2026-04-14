# Hướng Dẫn Kiểm Tra Hệ Thống MiniCloud

> **Tất cả dịch vụ đều truy cập qua Nginx Reverse Proxy tại port 8088.**  
> Các port 3000, 9001, 9090 **không expose ra ngoài** — chỉ dùng nội bộ Docker.
>
> Base URL: `http://localhost:8088`  
> Từ máy khác trong mạng LAN: thay `localhost` bằng IP máy chủ (vd: `http://10.0.205.103:8088`)
>
> **Lưu ý Windows PowerShell**: Dùng `curl.exe` thay vì `curl` (PowerShell alias `curl` trỏ vào `Invoke-WebRequest`, không hỗ trợ `-I`, `-s`)

---

## Tóm tắt Port & Credentials

| Service          | URL truy cập                          | Credentials                              |
|------------------|---------------------------------------|------------------------------------------|
| Nginx proxy      | http://localhost:8088                 | —                                        |
| Keycloak Admin   | http://localhost:8088/auth/admin      | admin / keycloak_admin_super_secret_123! |
| MinIO Console    | http://localhost:8088/minio/          | admin / minio_admin_secret_123! (cần login trước) |
| Grafana          | http://localhost:8088/grafana/        | admin / admin                            |
| Prometheus       | http://localhost:8088/prometheus/     | — (cần login trước)                      |
| DNS (nội bộ)     | —                                     | —                                        |

> **MinIO và Prometheus** được bảo vệ bằng cookie auth — cần đăng nhập tại `http://localhost:8088` trước.

---

## 1. Kiểm tra API Gateway Proxy — Nginx Reverse Proxy

> Mục đích: Xác minh routing hợp nhất qua một cổng duy nhất (port 8088).

### Linux / macOS
```bash
# Web frontend (round-robin web1/web2)
curl -I http://localhost:8088/

# App backend
curl -s http://localhost:8088/api/hello

# Auth (Keycloak)
curl -I http://localhost:8088/auth/
```

### Windows (CMD)
```cmd
curl -I http://localhost:8088/
curl -s http://localhost:8088/api/hello
curl -I http://localhost:8088/auth/
```

### Windows (PowerShell)
```powershell
curl.exe -I http://localhost:8088/
curl.exe -s http://localhost:8088/api/hello
curl.exe -I http://localhost:8088/auth/
```

**Kết quả mong đợi:**
```
Web:  HTTP/1.1 200 OK  (Content-Type: text/html)
App:  {"message": "Hello from Modular App Server!"}
Auth: HTTP/1.1 302 Found  (Location: /auth/admin/)
```

---

## 2. Kiểm tra Flask App API

### Linux / macOS & Windows (CMD)
```bash
curl http://localhost:8088/api/hello
curl -H "Accept: application/json" http://localhost:8088/api/student
curl -H "Accept: application/json" http://localhost:8088/api/notes
curl http://localhost:8088/api/register_demo
```

### Windows (PowerShell)
```powershell
curl.exe http://localhost:8088/api/hello
curl.exe -H "Accept: application/json" http://localhost:8088/api/student
curl.exe -H "Accept: application/json" http://localhost:8088/api/notes
curl.exe http://localhost:8088/api/register_demo
```

**Kết quả mong đợi:**
```json
// /api/hello
{"message": "Hello from Modular App Server!"}

// /api/register_demo
{"thong_bao": "Sẵn sàng lưu vào DB", "hash_se_luu": "pbkdf2:sha256:..."}
```

---

## 3. Kiểm tra khi DB không khả dụng (HTTP 503)

```bash
docker stop minicloud-db
curl -v http://localhost:8088/api/student
# Kết quả mong đợi: HTTP 503
docker start minicloud-db
```

---

## 4. Kiểm tra dịch vụ đăng nhập OIDC — Keycloak

> Realm: `realm_52300267` | Client: `flask-app`  
> Admin UI: **http://localhost:8088/auth/admin**  
> Admin: `admin` / `keycloak_admin_super_secret_123!`

### Bước 1 — Kiểm tra Keycloak đang chạy

```bash
# Qua proxy
curl http://localhost:8088/auth/health/ready

# Trực tiếp trong container
docker exec minicloud-auth curl -s http://127.0.0.1:9000/auth/health/ready
```

**Kết quả mong đợi:** `{"status": "UP"}`

---

### Bước 2 — Discovery Endpoint

```bash
curl http://localhost:8088/auth/realms/realm_52300267/.well-known/openid-configuration
```

**Kết quả mong đợi:** JSON chứa `issuer`, `authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`

---

### Bước 3 — Lấy Admin Token + Tạo User test

#### Linux / macOS
```bash
ADMIN_TOKEN=$(curl -s -X POST \
  "http://localhost:8088/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli&username=admin&password=keycloak_admin_super_secret_123!&grant_type=password" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Kiểm tra realm tồn tại
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8088/auth/admin/realms/realm_52300267" | python3 -m json.tool

# Tạo user test
curl -s -X POST \
  "http://localhost:8088/auth/admin/realms/realm_52300267/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","enabled":true,"credentials":[{"type":"password","value":"testpass","temporary":false}]}'
```

#### Windows (PowerShell)
```powershell
$adminResp = Invoke-WebRequest -Uri "http://localhost:8088/auth/realms/master/protocol/openid-connect/token" `
    -Method POST -Body @{client_id="admin-cli";username="admin";password="keycloak_admin_super_secret_123!";grant_type="password"}
$ADMIN_TOKEN = ($adminResp.Content | ConvertFrom-Json).access_token

Invoke-WebRequest -Uri "http://localhost:8088/auth/admin/realms/realm_52300267/users" `
    -Method POST `
    -Headers @{"Authorization"="Bearer $ADMIN_TOKEN";"Content-Type"="application/json"} `
    -Body '{"username":"testuser","enabled":true,"credentials":[{"type":"password","value":"testpass","temporary":false}]}'
```

---

### Bước 4 — Lấy Access Token (đăng nhập user)

#### Linux / macOS
```bash
TOKEN_RESP=$(curl -s -X POST \
  "http://localhost:8088/auth/realms/realm_52300267/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=flask-app&username=testuser&password=testpass&grant_type=password")

ACCESS_TOKEN=$(echo $TOKEN_RESP | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "Token: $ACCESS_TOKEN"
```

#### Windows (CMD)
```cmd
curl -s -X POST "http://localhost:8088/auth/realms/realm_52300267/protocol/openid-connect/token" ^
  -H "Content-Type: application/x-www-form-urlencoded" ^
  -d "client_id=flask-app&username=testuser&password=testpass&grant_type=password"
```

#### Windows (PowerShell)
```powershell
$tokenResp = Invoke-WebRequest -Uri "http://localhost:8088/auth/realms/realm_52300267/protocol/openid-connect/token" `
    -Method POST -Body @{client_id="flask-app";username="testuser";password="testpass";grant_type="password"}
$ACCESS_TOKEN = ($tokenResp.Content | ConvertFrom-Json).access_token
Write-Host "Token: $ACCESS_TOKEN"
```

**Kết quả mong đợi:** JSON chứa `access_token`, `refresh_token`, `token_type: Bearer`

---

### Bước 5 — UserInfo + Introspect Token

#### Linux / macOS
```bash
# UserInfo
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "http://localhost:8088/auth/realms/realm_52300267/protocol/openid-connect/userinfo" | python3 -m json.tool

# Introspect
curl -s -X POST \
  "http://localhost:8088/auth/realms/realm_52300267/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=flask-app&token=$ACCESS_TOKEN" | python3 -m json.tool
```

**Kết quả mong đợi:**
```json
// UserInfo
{"sub": "...", "preferred_username": "testuser"}

// Introspect
{"active": true, ...}
```

---

### Bước 6 — Gọi API bảo mật + Kiểm tra từ chối token giả

#### Linux / macOS
```bash
# Với token hợp lệ → HTTP 200
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json" \
  http://localhost:8088/api/student/secure

# Với token giả → HTTP 401
curl -v -H "Authorization: Bearer token_gia_mao_123" http://localhost:8088/api/student/secure
```

#### Windows (PowerShell)
```powershell
curl.exe -s -H "Authorization: Bearer $ACCESS_TOKEN" -H "Accept: application/json" http://localhost:8088/api/student/secure
curl.exe -v -H "Authorization: Bearer token_gia_mao_123" http://localhost:8088/api/student/secure
```

---

## 5. Kiểm tra Object Storage MinIO (tương đương Amazon S3)

> Console UI: **http://localhost:8088/minio/** (cần đăng nhập tại trang chủ trước)  
> Credentials: `admin` / `minio_admin_secret_123!`  
> Port 9000 (S3 API) và 9001 (Console) không expose ra ngoài — dùng `docker exec` hoặc qua proxy.

### Bước 1 — Health check

```bash
docker exec minicloud-storage curl -sf http://127.0.0.1:9000/minio/health/live && echo "MinIO OK"
```

---

### Bước 2 — Liệt kê bucket + object qua S3 API

```bash
# Liệt kê tất cả buckets
docker exec minicloud-storage curl -s --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" "http://127.0.0.1:9000/"

# Liệt kê objects trong bucket my-first-bucket
docker exec minicloud-storage curl -s --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" "http://127.0.0.1:9000/my-first-bucket?list-type=2"

# Tạo bucket mới
docker exec minicloud-storage curl -s -X PUT --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" "http://127.0.0.1:9000/mybucket"

# Upload file text
docker exec minicloud-storage curl -s -X PUT --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" -H "Content-Type: text/plain" --data "Hello from MiniCloud S3!" "http://127.0.0.1:9000/mybucket/hello.txt"

# Download object
docker exec minicloud-storage curl -s --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" "http://127.0.0.1:9000/mybucket/hello.txt"

# Xóa object
docker exec minicloud-storage curl -s -X DELETE --user "admin:minio_admin_secret_123!" --aws-sigv4 "aws:amz:us-east-1:s3" "http://127.0.0.1:9000/mybucket/hello.txt"
```

---

### Bước 3 — Dùng MinIO Client (mc)

#### Linux / macOS
```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc && sudo mv mc /usr/local/bin/
mc alias set minicloud http://localhost:9000 admin minio_admin_secret_123!
mc ls minicloud
mc mb minicloud/test-bucket
echo "Hello MinIO" > test.txt && mc cp test.txt minicloud/test-bucket/
mc ls minicloud/test-bucket
```

#### Windows (PowerShell)
```powershell
Invoke-WebRequest -Uri "https://dl.min.io/client/mc/release/windows-amd64/mc.exe" -OutFile "mc.exe"
.\mc.exe alias set minicloud http://localhost:9000 admin minio_admin_secret_123!
.\mc.exe ls minicloud
.\mc.exe mb minicloud/test-bucket
```

> **Lưu ý:** MinIO S3 API (port 9000) không expose ra ngoài. Dùng `docker exec` hoặc kết nối từ bên trong Docker network.

---

## 6. Kiểm tra DNS Bind9 — Phân giải tên miền nội bộ

> DNS chỉ phục vụ trong mạng nội bộ Docker — dùng `docker exec`.

### Bước 1 — Health check + Truy vấn bản ghi

```bash
docker exec minicloud-dns dig @127.0.0.1 localhost
docker exec minicloud-dns dig @127.0.0.1 web-frontend-server.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 monitoring-node-exporter-server.cloud.local A
```

**Kết quả mong đợi:**
```
web-frontend-server.cloud.local.  604800 IN A 10.10.1.11
monitoring-node-exporter-server.cloud.local. 604800 IN A 10.10.3.19
```

---

### Bước 2 — Truy vấn tất cả bản ghi trong zone

```bash
docker exec minicloud-dns dig @127.0.0.1 cloud.local AXFR
docker exec minicloud-dns dig @127.0.0.1 web1.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 web2.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 app.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 auth.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 db.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 storage.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 monitoring.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 grafana.cloud.local A
docker exec minicloud-dns dig @127.0.0.1 proxy.cloud.local A
```

---

### Bước 3 — Kiểm tra end-to-end từ container khác

```bash
docker exec minicloud-app nslookup db.cloud.local
docker exec minicloud-app nslookup web-frontend-server.cloud.local 10.10.3.53
```

---

### Bước 4 — Reload zone sau khi sửa config

```bash
docker exec minicloud-dns rndc reload
```

---

## 7. Kiểm tra Monitoring — Node Exporter + Prometheus

> Prometheus UI: **http://localhost:8088/prometheus/** (cần đăng nhập tại trang chủ trước)  
> Scrape interval: 15s

### Bước 1 — Kiểm tra tất cả targets UP

```bash
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/api/v1/targets?state=active" | python3 -c "import sys,json; targets=json.load(sys.stdin)['data']['activeTargets']; [print(t['labels']['job'], '-', t['health']) for t in targets]"
```

**Kết quả mong đợi:**
```
app - up
db - up
node-exporter - up
prometheus - up
web - up
```

---

### Bước 2 — Kiểm tra Node Exporter metrics

```bash
# CPU
docker exec minicloud-node-exporter wget -qO- http://localhost:9100/metrics | grep "node_cpu_seconds_total" | head -5

# RAM
docker exec minicloud-node-exporter wget -qO- http://localhost:9100/metrics | grep "node_memory_MemAvailable_bytes"

# Disk
docker exec minicloud-node-exporter wget -qO- http://localhost:9100/metrics | grep "node_filesystem_avail_bytes" | head -3
```

---

### Bước 3 — Query PromQL

```bash
# CPU usage (%)
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/api/v1/query?query=100-(avg(rate(node_cpu_seconds_total{mode='idle'}[1m]))*100)"

# RAM còn trống
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes"

# Kiểm tra node-exporter UP (kết quả "1" = UP)
docker exec minicloud-monitoring wget -qO- "http://localhost:9090/api/v1/query?query=up{job='node-exporter'}"
```

---

### Bước 4 — Prometheus health

```bash
docker exec minicloud-monitoring wget -qO- http://localhost:9090/-/healthy
docker exec minicloud-monitoring wget -qO- http://localhost:9090/-/ready
```

**Kết quả mong đợi:** `Prometheus Server is Healthy.`

---

## 8. Kiểm tra Grafana Dashboard

> Grafana UI: **http://localhost:8088/grafana/**  
> Đăng nhập: `admin` / `admin` (đổi password lần đầu)

### Bước 1 — Thêm Prometheus datasource

1. **Connections** → **Data sources** → **Add data source** → **Prometheus**
2. URL: `http://minicloud-monitoring:9090`
3. **Save & test** → `Successfully queried the Prometheus API`

### Bước 2 — Import dashboard Node Exporter

1. **Dashboards** → **Import** → ID: `1860` → **Load**
2. Chọn datasource `prometheus` → **Import**

### Bước 3 — Health check API

```bash
docker exec minicloud-grafana wget -qO- http://localhost:3000/api/health
```

**Kết quả mong đợi:** `{"commit":"...","database":"ok","version":"..."}`

---

## 9. Truy vấn trực tiếp MariaDB

### Linux / macOS
```bash
docker exec minicloud-db mariadb -uroot -p$(cat MiniCloud/secrets/db_root_password.txt) -e "SELECT * FROM minicloud.notes;"
docker exec minicloud-db mariadb -uroot -p$(cat MiniCloud/secrets/db_root_password.txt) -e "SELECT * FROM studentdb.students;"
docker exec minicloud-db mariadb -uroot -p$(cat MiniCloud/secrets/db_root_password.txt) -e "SHOW DATABASES;"
```

### Windows (CMD)
```cmd
docker exec minicloud-db mariadb -uroot -psuper_secure_root_password! -e "SELECT * FROM minicloud.notes;"
docker exec minicloud-db mariadb -uroot -psuper_secure_root_password! -e "SELECT * FROM studentdb.students;"
docker exec minicloud-db mariadb -uroot -psuper_secure_root_password! -e "SHOW DATABASES;"
```

### Windows (PowerShell)
```powershell
$ROOT_PASS = (Get-Content MiniCloud\secrets\db_root_password.txt).Trim()
docker exec minicloud-db mariadb -uroot -p$ROOT_PASS -e "SELECT * FROM minicloud.notes;"
docker exec minicloud-db mariadb -uroot -p$ROOT_PASS -e "SELECT * FROM studentdb.students;"
docker exec minicloud-db mariadb -uroot -p$ROOT_PASS -e "SHOW DATABASES;"
```

**Kết quả mong đợi:**
```
id  title                  created_at
1   Hello from MariaDB!    2026-04-13 09:25:45
```

---

## 10. Kiểm tra thông mạng nội bộ — Ping tất cả server

> Dùng container `app` làm điểm ping (có mặt trong cả 3 network).

```bash
docker exec minicloud-app sh -c "
echo '=== proxy/nginx    (10.10.1.10) ===' && ping -c 2 proxy.cloud.local    2>&1 | tail -2
echo '=== web1           (10.10.1.11) ===' && ping -c 2 web1.cloud.local     2>&1 | tail -2
echo '=== web2           (10.10.1.20) ===' && ping -c 2 web2.cloud.local     2>&1 | tail -2
echo '=== app            (10.10.1.12) ===' && ping -c 2 app.cloud.local      2>&1 | tail -2
echo '=== auth/keycloak  (10.10.1.13) ===' && ping -c 2 auth.cloud.local     2>&1 | tail -2
echo '=== db             (10.10.2.14) ===' && ping -c 2 db.cloud.local       2>&1 | tail -2
echo '=== storage/minio  (10.10.2.15) ===' && ping -c 2 storage.cloud.local  2>&1 | tail -2
echo '=== prometheus     (10.10.3.16) ===' && ping -c 2 monitoring.cloud.local 2>&1 | tail -2
echo '=== grafana        (10.10.3.18) ===' && ping -c 2 grafana.cloud.local  2>&1 | tail -2
echo '=== dns            (10.10.3.53) ===' && ping -c 2 dns.cloud.local      2>&1 | tail -2
"
```

**Kết quả mong đợi:** Tất cả 10 server `0% packet loss`

---

## 11. Kiểm tra Docker containers

```bash
# Xem tất cả container và trạng thái
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Xem logs
docker logs minicloud-app
docker logs minicloud-auth
docker logs minicloud-db
docker logs minicloud-proxy
docker logs minicloud-storage
docker logs minicloud-monitoring

# Theo dõi realtime
docker logs -f minicloud-app
```

---

## 12. Chạy Unit Tests (pytest)

### Linux / macOS
```bash
cd MiniCloud/app
python -m pytest tests/ -v
```

### Windows (CMD)
```cmd
cd MiniCloud\app
python -m pytest tests/ -v
```

### Windows (PowerShell)
```powershell
Set-Location MiniCloud\app
python -m pytest tests/ -v
```
