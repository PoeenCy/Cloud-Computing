import mysql.connector
import os


def _read_db_password_secret():
    """Đọc mật khẩu DB từ Docker Secret (mount tại /run/secrets/db_password)."""
    path = '/run/secrets/db_password'
    if not os.path.exists(path):
        raise RuntimeError('Thiếu secret db_password — kiểm tra docker-compose (service app: secrets).')
    with open(path, 'r', encoding='utf-8') as f:
        return f.read().strip()

def get_db_connection():
    # Đọc password từ file secret mà Docker đã mount vào container
    try:
        with open('/run/secrets/db_password', 'r') as f:
            db_pass = f.read().strip()
    except Exception as e:
        print(f"Không thể đọc file secret: {e}")
        return None

    try:
        conn = mysql.connector.connect(
            host='10.10.2.14',       # IP của minicloud-db trong backend-net
            user='admin',
            password=db_pass,
            database='studentdb'     # Tên DB bạn đã tạo trong file init.sql
        )
        return conn
    except mysql.connector.Error as err:
        print(f"Lỗi kết nối MariaDB: {err}")
        return None