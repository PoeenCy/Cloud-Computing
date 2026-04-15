Thư mục này chứa **Docker Secrets** dạng file một dòng mỗi file. **Không commit** các file `.txt` thật lên Git (đã nằm trong `.gitignore`).

Tạo cục bộ các file:

- `db_root_password.txt` - MariaDB root password
- `db_password.txt` - MariaDB user password
- `kc_admin_password.txt` - Keycloak admin password
- `storage_root_user.txt` - MinIO root username
- `storage_root_pass.txt` - MinIO root password
- `minio_oidc_client_secret.txt` - MinIO OIDC Client Secret từ Keycloak

## Cách tạo MinIO OIDC Client Secret

1. Truy cập Keycloak Admin Console: http://localhost:8088/auth/
2. Chọn realm: `realm_52300267`
3. Vào **Clients** → Tìm client `minio`
4. Tab **Credentials** → Copy **Client secret**
5. Tạo file `minio_oidc_client_secret.txt` với nội dung là Client Secret (1 dòng, không có newline thừa)

Ví dụ:
```bash
echo -n "xbyxCAD1SlpBy937eMLVtJSQ33udpLfT" > minio_oidc_client_secret.txt
```

**Lưu ý**: Dùng `echo -n` để không thêm newline ở cuối file.

Nội dung thống nhất với nhóm và với biến trong `docker-compose.yml` (đặc biệt mật khẩu DB cho MariaDB và Keycloak).
