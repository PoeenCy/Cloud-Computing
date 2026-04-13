# Bugfix Requirements Document

## Introduction

Hai service cốt lõi của MiniCloud stack trên nhánh `day4-auth-infrastructure` bị crash khi khởi động:

- **minicloud-auth (Keycloak)** không kết nối được MariaDB do mật khẩu DB được hardcode trực tiếp trong biến môi trường `KC_DB_PASSWORD` thay vì đọc từ Docker Secret, dẫn đến "Access denied" khi MariaDB đã được khởi tạo với mật khẩu từ secret file. Ngoài ra, volume `db_data` cũ (từ lần chạy thử với PostgreSQL hoặc cấu hình khác) ngăn MariaDB tạo lại user/database mới, khiến Keycloak không thể kết nối và toàn bộ realm/client/user bị mất sau mỗi lần rebuild.

- **minicloud-app (Flask)** bị exit ngay khi khởi động do `run.py` import `from src import create_app` nhưng khi container chạy với volume mount `./app:/app`, Python không tìm thấy package `src` nếu thiếu `__init__.py` ở thư mục gốc `/app`, hoặc `database.py` ném exception chưa được bắt khi secret file không tồn tại, khiến app sụp đổ trước khi bind port 8081.

---

## Bug Analysis

### Current Behavior (Defect)

**Bug 1 — Keycloak không kết nối được MariaDB:**

1.1 WHEN service `auth` khởi động với `KC_DB_PASSWORD` được hardcode là `"secure_db_password_123!"` trong `docker-compose.yml` THEN Keycloak cố kết nối MariaDB bằng mật khẩu đó nhưng MariaDB đã được khởi tạo với mật khẩu khác từ `/run/secrets/db_password`, dẫn đến lỗi "Access denied for user 'admin'@'...'"

1.2 WHEN volume `minicloud_db_data` đã tồn tại từ lần chạy trước (với schema PostgreSQL hoặc cấu hình MariaDB khác) THEN MariaDB bỏ qua toàn bộ script trong `docker-entrypoint-initdb.d/`, không tạo lại user `admin` và database `minicloud`, khiến Keycloak không thể đăng nhập

1.3 WHEN Keycloak không kết nối được DB THEN container `minicloud-auth` bị đánh dấu Unhealthy, service `proxy` (phụ thuộc `auth`) không khởi động được, toàn bộ stack bị treo

1.4 WHEN stack được rebuild mà không xóa volume `db_data` THEN dữ liệu Realm, Client và User của Keycloak bị mất vì Keycloak không thể ghi vào DB

**Bug 2 — Flask app exit ngay khi khởi động:**

1.5 WHEN container `minicloud-app` khởi động và `run.py` thực thi `from src import create_app` THEN nếu Python không nhận diện được `src` là package hợp lệ (thiếu `__init__.py` hoặc PYTHONPATH không bao gồm `/app`), app ném `ModuleNotFoundError` và exit với code khác 0

1.6 WHEN `database.py` được import và hàm `_read_db_password_secret()` được gọi mà file `/run/secrets/db_password` chưa mount hoặc không tồn tại THEN hàm ném `RuntimeError` không được bắt, khiến Flask app crash trước khi bind port 8081

1.7 WHEN container `minicloud-app` exit ngay khi khởi động THEN healthcheck `wget -q --spider http://127.0.0.1:8081/api/hello` luôn thất bại, service bị đánh dấu Unhealthy và `proxy` không thể khởi động

---

### Expected Behavior (Correct)

**Fix 1 — Keycloak kết nối MariaDB thành công:**

2.1 WHEN service `auth` khởi động THEN Keycloak SHALL đọc mật khẩu DB từ Docker Secret thông qua biến `KC_DB_PASSWORD_FILE: /run/secrets/db_password` thay vì dùng giá trị hardcode, đảm bảo mật khẩu khớp với mật khẩu MariaDB được tạo từ cùng secret file

2.2 WHEN volume `minicloud_db_data` cũ tồn tại từ lần chạy trước với schema không tương thích THEN operator SHALL xóa volume (`docker volume rm minicloud_db_data`) trước khi chạy lại stack để MariaDB thực thi lại `docker-entrypoint-initdb.d/` và tạo đúng user/database

2.3 WHEN Keycloak kết nối DB thành công THEN container `minicloud-auth` SHALL chuyển sang trạng thái Healthy sau `start_period`, cho phép `proxy` khởi động bình thường

2.4 WHEN stack chạy ổn định THEN dữ liệu Realm, Client và User của Keycloak SHALL được lưu bền vững trong volume `db_data` và không bị mất sau khi restart container

**Fix 2 — Flask app khởi động thành công:**

2.5 WHEN container `minicloud-app` khởi động THEN Flask app SHALL import `src` thành công và bind port 8081, endpoint `/api/hello` SHALL trả về HTTP 200

2.6 WHEN secret file `/run/secrets/db_password` chưa sẵn sàng tại thời điểm import THEN `database.py` SHALL không ném exception ở tầng module-level; exception chỉ được phép xảy ra khi `get_db_connection()` được gọi thực sự (lazy connection)

2.7 WHEN `get_db_connection()` thất bại do DB chưa sẵn sàng THEN Flask SHALL trả về HTTP 503 thay vì crash toàn bộ process

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN Keycloak đã kết nối DB thành công và realm được cấu hình THEN hệ thống SHALL CONTINUE TO phục vụ Keycloak dashboard tại `localhost:8088/auth` và xử lý các luồng OAuth2/OIDC bình thường

3.2 WHEN Flask app đang chạy bình thường và DB sẵn sàng THEN hệ thống SHALL CONTINUE TO trả về HTTP 200 tại `/api/hello` với payload `{"message": "Hello from Modular App Server!"}`

3.3 WHEN các service khác (dns, db, web, storage, monitoring) đang hoạt động bình thường THEN việc fix 2 lỗi trên SHALL CONTINUE TO không ảnh hưởng đến cấu hình mạng micro-segmentation (3 network zones), DNS Bind9, Nginx routing, MinIO, Prometheus/Grafana

3.4 WHEN Docker Secrets đang được sử dụng cho MariaDB, MinIO THEN hệ thống SHALL CONTINUE TO quản lý credentials qua secret files trong `./secrets/`, không hardcode mật khẩu trong `docker-compose.yml`

3.5 WHEN `run.py` chạy với `python run.py` từ thư mục `/app` THEN hệ thống SHALL CONTINUE TO sử dụng cấu trúc module `src/` với `src/__init__.py` chứa `create_app()` factory function

---

## Bug Condition (Pseudocode)

### Bug 1 — Keycloak DB Password Mismatch

```pascal
FUNCTION isBugCondition_KC(config)
  INPUT: config — docker-compose auth service environment block
  OUTPUT: boolean

  RETURN (config.KC_DB_PASSWORD is hardcoded string)
      OR (volume "minicloud_db_data" exists AND was created with different schema)
END FUNCTION

// Property: Fix Checking
FOR ALL config WHERE isBugCondition_KC(config) DO
  result ← startKeycloak'(config)
  ASSERT result.status = "healthy"
    AND result.db_connection = "success"
    AND result.password_source = "docker_secret"
END FOR

// Property: Preservation Checking
FOR ALL config WHERE NOT isBugCondition_KC(config) DO
  ASSERT startKeycloak(config) = startKeycloak'(config)
END FOR
```

### Bug 2 — Flask Startup Crash

```pascal
FUNCTION isBugCondition_Flask(env)
  INPUT: env — container runtime environment
  OUTPUT: boolean

  RETURN (env.PYTHONPATH does NOT include "/app")
      OR (secret_file "/run/secrets/db_password" raises exception at import time)
      OR (module "src" raises ModuleNotFoundError)
END FUNCTION

// Property: Fix Checking
FOR ALL env WHERE isBugCondition_Flask(env) DO
  result ← startFlask'(env)
  ASSERT result.exit_code = 0
    AND result.port_8081 = "bound"
    AND GET("/api/hello").status = 200
END FOR

// Property: Preservation Checking
FOR ALL env WHERE NOT isBugCondition_Flask(env) DO
  ASSERT startFlask(env) = startFlask'(env)
END FOR
```
