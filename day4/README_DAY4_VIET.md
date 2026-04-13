# Báo cáo kết quả công việc - Day 4 (12/04/2026)
**Người thực hiện:** Huỳnh Nguyễn Quốc Việt

## 1. Công việc đã hoàn thành
- **Triển khai Reverse Proxy:** Cấu hình thành công Nginx để quản lý luồng truy cập tập trung vào cổng 8088.
- **Tối ưu Docker Networking:** Thiết lập hệ thống 3 mạng độc lập (frontend, backend, mgmt) giúp tăng tính bảo mật cho Database và Auth service.
- **Cấu hình Keycloak Quarkus:** Chạy thành công Keycloak với hậu tố `/auth` (Relative Path) sau Proxy.
- **Đồng bộ hóa Client Secrets:** Cấu hình file JSON cho Flask App hỗ trợ giao tiếp đa kênh (nội bộ Docker và trình duyệt người dùng).

## 2. Các lỗi đã xử lý
- **Lỗi 502/404 Nginx:** Sửa lỗi do thừa dấu xuyệt `/` trong `proxy_pass` và sai lệch Port mapping.
- **Lỗi Page Not Found (Keycloak):** Điều chỉnh lại biến `KC_HOSTNAME_URL` để tránh trùng lặp prefix `/auth`.

## 3. Tình trạng hiện tại và Vấn đề tồn đọng
- **Tình trạng:** Hệ thống chạy ổn định, đã truy cập được vào trang quản trị Admin.
- **Lỗi hiện tại:** Dữ liệu cấu hình (Realms, Clients) chưa được lưu trữ bền vững (Persistence) sau khi rebuild container. Cần kiểm tra lại cấu hình Volume của MariaDB.
- **Kế hoạch:** Tái thiết lập Realm và Client để test luồng login thực tế của ứng dụng.