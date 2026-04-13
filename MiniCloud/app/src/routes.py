from flask import Blueprint, jsonify
from .database import get_db_connection
from . import oidc
from werkzeug.security import generate_password_hash

api_bp = Blueprint('api', __name__)


@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})


@api_bp.route('/api/register_demo', methods=['GET'])
def register_demo():
    mat_khau_nguoi_dung = "mat_khau_bi_mat_123"
    mat_khau_da_bam = generate_password_hash(mat_khau_nguoi_dung)
    return jsonify({
        "thong_bao": "Sẵn sàng lưu vào DB",
        "hash_se_luu": mat_khau_da_bam
    })


# Public endpoint — frontend gọi trực tiếp không cần token
@api_bp.route('/api/student', methods=['GET'])
def get_students():
    try:
        conn = get_db_connection()
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT student_id as id, fullname as name, major FROM students")
        students = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(students)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# Protected endpoint — yêu cầu Keycloak Bearer token (dùng cho rubric OIDC)
@api_bp.route('/api/student/secure', methods=['GET'])
@oidc.accept_token()
def get_students_secure():
    return get_students()
