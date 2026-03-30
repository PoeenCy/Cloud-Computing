from flask import Blueprint, jsonify
from .database import get_db_connection
from . import oidc  # Gọi ổ khóa từ file __init__

api_bp = Blueprint('api', __name__)

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})

# Thêm "ổ khóa" bắt buộc đăng nhập vào đây
@api_bp.route('/api/student', methods=['GET'])
@oidc.require_login
def get_students():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT id, student_id, fullname, dob, major FROM studentdb.students")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": str(e)}), 500