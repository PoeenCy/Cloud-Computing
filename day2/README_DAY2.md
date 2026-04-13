Hướng Dẫn Chạy Project - Day 2 (Identity Management)
Sinh viên thực hiện: Huỳnh Nguyễn Quốc Việt
MSSV: 52300267

1. Giới thiệu
Nhiệm vụ này hoàn thành việc kết nối Backend với MariaDB và thiết lập hệ thống quản lý định danh (IAM) bằng Keycloak 26.x.

2. Các thành phần đã hoàn thiện
Database: Khởi tạo studentdb, bảng students và cấp quyền cho user admin.

Backend (Flask): Viết API /api/student truy vấn dữ liệu trực tiếp từ MariaDB.

IAM (Keycloak): Cấu hình Realm, Client và User để chuẩn bị cho phần phân quyền.

3. Cách triển khai (Deployment)
Để tránh xung đột với cấu hình mạng phức tạp, project hiện tại sử dụng file docker-compose.yml tối giản.

Lệnh khởi chạy:

Bash
docker compose up -d --build
4. Thông tin truy cập (Credentials)
Backend API: http://localhost:8081/api/student

Keycloak Console: http://localhost:8080

Admin User: admin

Admin Password: keycloak_admin_super_secret_123!

Cấu hình Keycloak đã thiết lập:

Realm: realm_52300267

Client ID: flask-app (Public Client)

Test Users:

sv01 / mật khẩu: 123456

sv02 / mật khẩu: 123456

5. Cấu trúc thư mục quan trọng
app/src/routes.py: Chứa logic xử lý API lấy danh sách sinh viên.

app/src/database.py: Chứa cấu hình kết nối MariaDB (Host: db).

db-init/001_init.sql: Script khởi tạo database và phân quyền SQL.

secrets/: Chứa các file mật khẩu cho Docker Secrets.