from flask import Blueprint, jsonify
from .database import get_db_connection
from . import oidc  # Gọi ổ khóa từ file __init__
from werkzeug.security import generate_password_hash # Thêm thư viện băm mật khẩu

api_bp = Blueprint('api', __name__)

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})

# --- TASK 1: API Đăng ký sinh viên (Băm mật khẩu) ---
@api_bp.route('/api/register_demo', methods=['GET'])
def register_demo():
    # Giả lập mật khẩu do người dùng nhập vào
    mat_khau_nguoi_dung = "mat_khau_bi_mat_123"
    
    # Băm mật khẩu bằng werkzeug.security
    mat_khau_da_bam = generate_password_hash(mat_khau_nguoi_dung)
    
    # Trả về kết quả để kiểm tra (Trong thực tế sẽ lưu mat_khau_da_bam vào Database)
    return jsonify({
        "thong_bao": "Sẵn sàng lưu vào DB",
        "hash_se_luu": mat_khau_da_bam
    })

# --- TASK 2: API Lấy danh sách sinh viên (Khóa bằng Token) ---
# Thay đổi ổ khóa từ require_login (dành cho Web) sang accept_token (dành cho API Backend)
@api_bp.route('/api/student', methods=['GET'])
@oidc.accept_token()
def get_students():
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 500
    
    try:
        cursor = conn.cursor(dictionary=True)
        # Truy vấn các cột đúng như cấu trúc bảng students bạn đã tạo
        cursor.execute("SELECT student_id as id, fullname as name, major FROM students")
        students = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(students)
    except Exception as e:
        return jsonify({"error": str(e)}), 500