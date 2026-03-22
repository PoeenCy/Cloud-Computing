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
    """Kết nối MariaDB nội bộ tại db.cloud.local, database studentdb."""
    user = os.environ.get('DB_USER', 'admin')
    password = _read_db_password_secret()
    # TODO (Việt): Bổ sung try/except, retry, hoặc connection pool nếu cần production
    return mysql.connector.connect(
        host='db.cloud.local',
        port=3306,
        user=user,
        password=password,
        database='studentdb',
    )
