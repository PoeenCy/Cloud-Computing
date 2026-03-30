import os
import mysql.connector

def _read_db_password_secret():
    """Đọc mật khẩu DB từ Docker Secret (mount tại /run/secrets/db_password)."""
    path = '/run/secrets/db_password'
    if not os.path.exists(path):
        raise RuntimeError('Thiếu secret db_password — kiểm tra docker-compose (service app: secrets).')
    with open(path, 'r', encoding='utf-8') as f:
        return f.read().strip()

def get_db_connection():
    """Kết nối MariaDB nội bộ tại service 'db', database studentdb."""
    # Bỏ qua biến môi trường, gán cứng tài khoản chuẩn
    password = _read_db_password_secret()
    
    return mysql.connector.connect(
        host='db', 
        port=3306,
        user='admin', # Sửa dòng này thành 'admin' (không có chữ s)
        password=password,
        database='studentdb',
    )
