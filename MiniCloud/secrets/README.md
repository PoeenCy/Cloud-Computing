Thư mục này chứa **Docker Secrets** dạng file một dòng mỗi file. **Không commit** các file `.txt` thật lên Git (đã nằm trong `.gitignore`).

Tạo cục bộ các file:

- `db_root_password.txt`
- `db_password.txt`
- `kc_admin_password.txt`
- `storage_root_user.txt`
- `storage_root_pass.txt`

Nội dung thống nhất với nhóm và với biến trong `docker-compose.yml` (đặc biệt mật khẩu DB cho MariaDB và Keycloak).
