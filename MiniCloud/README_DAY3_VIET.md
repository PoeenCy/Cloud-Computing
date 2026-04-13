## Hướng Dẫn Test Bảo Mật API (Day 3)
**Sinh viên thực hiện:** Huỳnh Nguyễn Quốc Việt
**MSSV:** 52300267

### 1. Mục tiêu đã hoàn thành
Tích hợp thành công Keycloak OIDC vào ứng dụng Flask. Endpoint `/api/student` hiện đã được bảo vệ bằng `@oidc.require_login`.

### 2. Yêu cầu BẮT BUỘC trước khi Test (Cấu hình DNS local)
Do luồng xác thực (Redirect) giao tiếp giữa Docker và máy Host, người chấm/test **BẮT BUỘC** phải thêm mapping sau vào file `hosts` của Windows (`C:\Windows\System32\drivers\etc\hosts`) để trình duyệt hiểu domain `auth`:
`127.0.0.1       auth`

### 3. Kịch bản Nghiệm thu
1. Khởi động hệ thống: `docker compose up -d`
2. Mở trình duyệt (khuyên dùng tab Ẩn danh) và truy cập: `http://localhost:8081/api/student`
3. Hệ thống sẽ tự động chặn và chuyển hướng sang trang đăng nhập Keycloak (`http://auth:8080/...`).
4. Tiến hành đăng nhập bằng tài khoản test đã cấp:
   * **Username:** `sv01` (hoặc `sv02`)
   * **Password:** `123456`
5. Sau khi xác thực thành công, trình duyệt tự động quay về trang API và hiển thị chuỗi JSON chứa danh sách 5 sinh viên từ MariaDB.