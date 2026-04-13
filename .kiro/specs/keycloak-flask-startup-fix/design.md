# Keycloak Flask Startup Fix — Bugfix Design

## Overview

Hai service cốt lõi của MiniCloud stack bị crash khi khởi động do hai lỗi độc lập:

- **Bug 1 (Keycloak)**: `docker-compose.yml` hardcode `KC_DB_PASSWORD` và `KEYCLOAK_ADMIN_PASSWORD` trực tiếp trong `environment` block của service `auth`, trong khi MariaDB được khởi tạo bằng mật khẩu từ Docker Secret file. Kết quả: mật khẩu không khớp → "Access denied" → Keycloak Unhealthy → proxy không khởi động được.

- **Bug 2 (Flask)**: `database.py` ném `RuntimeError` không được bắt khi secret file `/run/secrets/db_password` không tồn tại. Nếu lỗi này xảy ra ở tầng module-level (hoặc khi `get_db_connection()` được gọi mà không có try/except), Flask crash trước khi bind port 8081. Ngoài ra, `routes.py` chưa có error handling cho DB failure, dẫn đến unhandled exception thay vì HTTP 503.

Chiến lược fix: tối thiểu, không thay đổi kiến trúc — chỉ sửa đúng 2 điểm gây crash, giữ nguyên toàn bộ cấu trúc thư mục, network zones, DNS, Nginx, và Docker Secrets pattern.

---

## Glossary

- **Bug_Condition (C)**: Điều kiện kích hoạt bug — (1) `KC_DB_PASSWORD` hardcoded trong `docker-compose.yml`, hoặc (2) `get_db_connection()` ném exception không được bắt khi secret file không tồn tại
- **Property (P)**: Hành vi đúng khi bug condition xảy ra — Keycloak đọc mật khẩu từ secret file; Flask trả về HTTP 503 thay vì crash
- **Preservation**: Các hành vi hiện tại phải giữ nguyên — `/api/hello` trả về 200, Keycloak dashboard hoạt động, toàn bộ network/DNS/Nginx không thay đổi
- **`KC_DB_PASSWORD_FILE`**: Biến môi trường Keycloak cho phép đọc mật khẩu DB từ file path thay vì giá trị trực tiếp
- **`KEYCLOAK_ADMIN_PASSWORD_FILE`**: Biến môi trường Keycloak cho phép đọc admin password từ file path
- **`_read_db_password_secret()`**: Hàm trong `database.py` đọc `/run/secrets/db_password`; hiện ném `RuntimeError` nếu file không tồn tại
- **`get_db_connection()`**: Hàm trong `database.py` gọi `_read_db_password_secret()` và tạo kết nối MariaDB
- **Docker Secret**: Cơ chế mount credential file vào `/run/secrets/<name>` trong container, không expose qua environment variable

---

## Bug Details

### Bug Condition

**Bug 1**: Service `auth` trong `docker-compose.yml` khai báo `KC_DB_PASSWORD` và `KEYCLOAK_ADMIN_PASSWORD` là giá trị hardcode trong `environment` block, trong khi đó secrets `db_password` và `kc_admin_password` đã được mount vào container nhưng không được sử dụng. MariaDB đọc mật khẩu từ `/run/secrets/db_password` (qua `MARIADB_PASSWORD_FILE`), còn Keycloak dùng giá trị hardcode khác → mismatch.

**Bug 2**: `get_db_connection()` trong `database.py` gọi `_read_db_password_secret()` mà không có try/except. Nếu `/run/secrets/db_password` không tồn tại (container chạy ngoài Docker Swarm/Compose, hoặc secret chưa mount), hàm ném `RuntimeError`. Trong `routes.py`, `get_db_connection()` chưa được bọc try/except, nên bất kỳ DB failure nào cũng gây unhandled exception thay vì HTTP 503.

**Formal Specification:**

```
FUNCTION isBugCondition(input)
  INPUT: input — (config: docker-compose auth env block) OR (env: container runtime)
  OUTPUT: boolean

  // Bug 1: Keycloak password mismatch
  IF input IS docker-compose-config THEN
    RETURN input.auth.environment["KC_DB_PASSWORD"] IS hardcoded_string
        OR input.auth.environment["KEYCLOAK_ADMIN_PASSWORD"] IS hardcoded_string

  // Bug 2: Flask DB secret not handled
  IF input IS flask-runtime-env THEN
    RETURN (NOT file_exists("/run/secrets/db_password")
            AND get_db_connection() raises unhandled exception)
        OR (get_db_connection() called from route without try/except)
END FUNCTION
```

### Examples

- **Bug 1 — Mismatch**: `KC_DB_PASSWORD: "secure_db_password_123!"` trong compose, nhưng `db_password.txt` chứa giá trị khác → Keycloak log: `Access denied for user 'admin'@'10.10.2.13'`
- **Bug 1 — Secret bị bỏ qua**: Secret `db_password` đã mount tại `/run/secrets/db_password` trong container `auth` nhưng Keycloak không đọc vì biến `KC_DB_PASSWORD_FILE` chưa được khai báo
- **Bug 2 — RuntimeError**: Container `app` khởi động, `get_db_connection()` được gọi khi secret chưa sẵn sàng → `RuntimeError: Thiếu secret db_password` → Flask crash, port 8081 không bind
- **Bug 2 — Unhandled exception**: Route `/api/student` gọi `get_db_connection()` khi DB down → exception không được bắt → HTTP 500 thay vì 503

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Endpoint `/api/hello` SHALL tiếp tục trả về HTTP 200 với payload `{"message": "Hello from Modular App Server!"}` khi Flask đang chạy bình thường
- Keycloak dashboard tại `localhost:8088/auth` SHALL tiếp tục hoạt động và xử lý OAuth2/OIDC sau khi fix
- Cấu hình mạng micro-segmentation (3 network zones: `frontend-net`, `backend-net`, `mgmt-net`) SHALL không thay đổi
- DNS Bind9, Nginx reverse proxy routing, MinIO, Prometheus/Grafana SHALL không bị ảnh hưởng
- Docker Secrets pattern cho MariaDB (`MARIADB_PASSWORD_FILE`) và MinIO (`MINIO_ROOT_PASSWORD_FILE`) SHALL giữ nguyên
- Cấu trúc thư mục `MiniCloud/` và module `src/` với `create_app()` factory SHALL không thay đổi

**Scope:**
Tất cả input KHÔNG thuộc bug condition (Keycloak đã dùng `_FILE` vars, Flask đang chạy với secret sẵn sàng) phải hoàn toàn không bị ảnh hưởng bởi fix này. Cụ thể:
- Các service khác trong stack (dns, db, web, storage, monitoring, loki, grafana)
- Các route Flask không gọi `get_db_connection()`
- Cấu hình network, volume, healthcheck của các service không liên quan

---

## Hypothesized Root Cause

Dựa trên phân tích code:

1. **Copy-paste từ plain environment sang secrets pattern (Bug 1)**: Khi thêm Docker Secrets vào `docker-compose.yml`, developer đã mount secrets đúng cách nhưng quên thay thế `KC_DB_PASSWORD` → `KC_DB_PASSWORD_FILE` và `KEYCLOAK_ADMIN_PASSWORD` → `KEYCLOAK_ADMIN_PASSWORD_FILE`. Keycloak hỗ trợ cả hai dạng biến, nhưng `_FILE` variant mới đọc từ secret file.

2. **Thiếu error handling trong `get_db_connection()` (Bug 2)**: `_read_db_password_secret()` được thiết kế đúng (chỉ đọc file khi được gọi, không phải module-level), nhưng caller `get_db_connection()` không có try/except. TODO comment trong code (`# TODO: Bổ sung try/except`) xác nhận đây là intentional gap chưa được implement.

3. **`routes.py` chưa implement error handling cho DB (Bug 2)**: Route `/api/student` có TODO comment nhưng chưa được implement. Quan trọng hơn, ngay cả khi implement, nếu không có try/except bao quanh `get_db_connection()`, bất kỳ DB failure nào cũng sẽ gây HTTP 500 thay vì 503.

4. **Volume cũ không tương thích (Bug 1 — operational)**: Nếu `minicloud_db_data` tồn tại từ lần chạy trước với schema khác, MariaDB bỏ qua `docker-entrypoint-initdb.d/`, không tạo lại user/database. Đây là vấn đề operational, không phải code bug, nhưng cần document rõ trong fix.

---

## Correctness Properties

Property 1: Bug Condition — Keycloak Reads Password from Docker Secret

_For any_ docker-compose configuration where `isBugCondition_KC` holds (tức là `KC_DB_PASSWORD` hoặc `KEYCLOAK_ADMIN_PASSWORD` đang hardcoded), service `auth` sau khi fix SHALL đọc mật khẩu từ Docker Secret thông qua `KC_DB_PASSWORD_FILE: /run/secrets/db_password` và `KEYCLOAK_ADMIN_PASSWORD_FILE: /run/secrets/kc_admin_password`, kết nối MariaDB thành công, và container chuyển sang trạng thái Healthy.

**Validates: Requirements 2.1, 2.3**

Property 2: Bug Condition — Flask Returns 503 Instead of Crashing

_For any_ Flask runtime environment where `isBugCondition_Flask` holds (tức là secret file không tồn tại hoặc DB không sẵn sàng khi route được gọi), hàm `get_db_connection()` sau khi fix SHALL ném `ConnectionError` được bắt bởi caller trong `routes.py`, và route SHALL trả về HTTP 503 thay vì crash toàn bộ Flask process.

**Validates: Requirements 2.6, 2.7**

Property 3: Preservation — Non-Buggy Inputs Unchanged

_For any_ input where bug condition KHÔNG xảy ra (Keycloak đã dùng `_FILE` vars, Flask đang chạy với secret sẵn sàng và DB healthy), toàn bộ hành vi của stack SHALL giống hệt trước khi fix: `/api/hello` trả về 200, Keycloak dashboard hoạt động, các service khác không bị ảnh hưởng.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

---

## Fix Implementation

### Changes Required

Giả sử root cause analysis đúng, cần thay đổi tối thiểu tại 2 file:

---

**File 1**: `MiniCloud/docker-compose.yml`

**Service**: `auth`

**Specific Changes**:

1. **Thay `KC_DB_PASSWORD` bằng `KC_DB_PASSWORD_FILE`**:
   - Xóa: `KC_DB_PASSWORD: "secure_db_password_123!"`
   - Thêm: `KC_DB_PASSWORD_FILE: /run/secrets/db_password`

2. **Thay `KEYCLOAK_ADMIN_PASSWORD` bằng `KEYCLOAK_ADMIN_PASSWORD_FILE`**:
   - Xóa: `KEYCLOAK_ADMIN_PASSWORD: "keycloak_admin_super_secret_123!"`
   - Thêm: `KEYCLOAK_ADMIN_PASSWORD_FILE: /run/secrets/kc_admin_password`

3. **Giữ nguyên**: Toàn bộ cấu hình network, secrets mount, healthcheck, depends_on, command

---

**File 2**: `MiniCloud/app/src/database.py`

**Function**: `get_db_connection()`

**Specific Changes**:

1. **Wrap `_read_db_password_secret()` trong try/except**:
   - Bắt `RuntimeError` từ `_read_db_password_secret()`
   - Re-raise dưới dạng `ConnectionError` để caller phân biệt được DB connection failure
   - Bắt `mysql.connector.Error` cho các lỗi kết nối MariaDB
   - Raise `ConnectionError` với message rõ ràng

---

**File 3**: `MiniCloud/app/src/routes.py`

**Function**: `get_students()` (và các route gọi DB trong tương lai)

**Specific Changes**:

1. **Thêm try/except bao quanh `get_db_connection()`**:
   - Bắt `ConnectionError` → trả về HTTP 503 với JSON error message
   - Pattern này áp dụng cho tất cả route gọi DB

---

### Operational Note (không phải code change)

Nếu volume `minicloud_db_data` tồn tại từ lần chạy trước với schema không tương thích, cần xóa trước khi chạy lại:
```bash
docker volume rm minicloud_db_data
```
Đây là bước manual, không tự động hóa trong code.

---

## Testing Strategy

### Validation Approach

Chiến lược kiểm thử theo hai giai đoạn: (1) chạy test trên code CHƯA fix để xác nhận bug tồn tại và root cause đúng; (2) chạy test sau khi fix để xác nhận fix đúng và không có regression.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples chứng minh bug TRƯỚC khi implement fix. Xác nhận hoặc bác bỏ root cause analysis.

**Test Plan**: Viết unit test simulate môi trường container với secret file không tồn tại, kiểm tra behavior của `get_db_connection()` và `routes.py`. Chạy trên code CHƯA fix để quan sát failure.

**Test Cases**:
1. **Secret File Missing Test**: Gọi `get_db_connection()` khi `/run/secrets/db_password` không tồn tại → expect `RuntimeError` (sẽ fail sau fix vì phải raise `ConnectionError`)
2. **Route DB Failure Test**: Gọi `GET /api/student` khi DB không sẵn sàng → expect HTTP 500 trên code chưa fix (sẽ trả về 503 sau fix)
3. **Compose Config Test**: Parse `docker-compose.yml` và assert `KC_DB_PASSWORD` không tồn tại trong `auth.environment` → sẽ fail trên code chưa fix
4. **Secret File Present Test**: Gọi `get_db_connection()` với mock secret file hợp lệ → expect không ném exception (baseline test)

**Expected Counterexamples**:
- `get_db_connection()` ném `RuntimeError` thay vì `ConnectionError` khi secret missing
- Route trả về HTTP 500 thay vì 503 khi DB fail
- `docker-compose.yml` chứa `KC_DB_PASSWORD` với giá trị hardcode

### Fix Checking

**Goal**: Xác nhận rằng với tất cả input thuộc bug condition, hàm sau khi fix cho ra hành vi đúng.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixedFunction(input)
  ASSERT expectedBehavior(result)
END FOR
```

**Cụ thể:**
- `docker-compose.yml` sau fix: `auth.environment` KHÔNG chứa `KC_DB_PASSWORD` hoặc `KEYCLOAK_ADMIN_PASSWORD`; chứa `KC_DB_PASSWORD_FILE` và `KEYCLOAK_ADMIN_PASSWORD_FILE`
- `get_db_connection()` sau fix: khi secret missing → raise `ConnectionError` (không phải `RuntimeError`, không crash)
- Route `/api/student` sau fix: khi `get_db_connection()` raise `ConnectionError` → trả về HTTP 503

### Preservation Checking

**Goal**: Xác nhận rằng với tất cả input KHÔNG thuộc bug condition, hành vi giữ nguyên.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalFunction(input) = fixedFunction(input)
END FOR
```

**Testing Approach**: Property-based testing được khuyến nghị cho preservation checking vì:
- Tự động sinh nhiều test case trên input domain
- Bắt được edge case mà unit test thủ công có thể bỏ sót
- Đảm bảo mạnh mẽ rằng hành vi không thay đổi cho tất cả non-buggy input

**Test Plan**: Quan sát behavior trên code CHƯA fix với các input bình thường, sau đó viết property-based test capture behavior đó.

**Test Cases**:
1. **Hello Endpoint Preservation**: `GET /api/hello` SHALL tiếp tục trả về HTTP 200 với đúng payload sau fix
2. **Compose Other Services Preservation**: Các service khác trong `docker-compose.yml` (db, web, proxy, storage...) SHALL không thay đổi cấu hình
3. **DB Connection Success Preservation**: Khi secret file tồn tại và DB healthy, `get_db_connection()` SHALL hoạt động bình thường như trước fix
4. **Module Import Preservation**: `from src import create_app` SHALL tiếp tục hoạt động, không có side effect ở module-level

### Unit Tests

- Test `get_db_connection()` với mock secret file tồn tại → expect kết nối thành công (mock mysql.connector)
- Test `get_db_connection()` với secret file không tồn tại → expect `ConnectionError` (sau fix)
- Test route `/api/hello` → expect HTTP 200 bất kể trạng thái DB
- Test route `/api/student` khi DB fail → expect HTTP 503 (sau fix)
- Test parse `docker-compose.yml`: assert `KC_DB_PASSWORD` không có trong `auth.environment` (sau fix)
- Test parse `docker-compose.yml`: assert `KC_DB_PASSWORD_FILE` có giá trị `/run/secrets/db_password` (sau fix)

### Property-Based Tests

- Sinh ngẫu nhiên các giá trị secret file content → `get_db_connection()` SHALL không crash ở bước đọc secret (chỉ có thể fail ở bước connect MariaDB)
- Sinh ngẫu nhiên các HTTP request đến `/api/hello` → SHALL luôn trả về 200 bất kể nội dung request
- Sinh ngẫu nhiên các trạng thái DB failure → route gọi DB SHALL luôn trả về 503 hoặc 2xx, không bao giờ crash process

### Integration Tests

- Khởi động Flask app với mock secret file → `GET /api/hello` trả về 200
- Khởi động Flask app không có secret file → app vẫn start, `GET /api/hello` trả về 200, `GET /api/student` trả về 503
- Verify `docker-compose.yml` config: service `auth` dùng `_FILE` variants, không có hardcoded password
- Verify secrets mount: container `auth` có `/run/secrets/db_password` và `/run/secrets/kc_admin_password` accessible
