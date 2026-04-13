import mysql.connector
import os


def _read_db_password_secret():
    """Đọc mật khẩu DB từ Docker Secret (mount tại /run/secrets/db_password)."""
    path = '/run/secrets/db_password'
    if not os.path.exists(path):
        raise RuntimeError('Thiếu secret db_password — kiểm tra docker-compose (service app: secrets).')
    with open(path, 'r', encoding='utf-8') as f:
        return f.read().strip()


def get_db_connection(database=None):
    """Kết nối MariaDB qua DNS nội bộ db.cloud.local.
    Raise ConnectionError nếu secret thiếu hoặc DB không sẵn sàng.
    """
    try:
        db_pass = _read_db_password_secret()
    except RuntimeError as e:
        raise ConnectionError(f"Không thể đọc secret DB: {e}") from e

    try:
        conn = mysql.connector.connect(
            host='db.cloud.local',
            port=3306,
            user=os.environ.get('DB_USER', 'admin'),
            password=db_pass,
            database=database or os.environ.get('DB_NAME', 'studentdb'),
        )
        return conn
    except mysql.connector.Error as err:
        raise ConnectionError(f"Lỗi kết nối MariaDB: {err}") from err
