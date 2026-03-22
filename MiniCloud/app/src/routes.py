from flask import Blueprint, jsonify
from .database import get_db_connection

api_bp = Blueprint('api', __name__)

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})

@api_bp.route('/api/student', methods=['GET'])
def get_students():
    # TODO (Việt): Viết truy vấn SQL lấy danh sách sinh viên từ bảng students
    # Gợi ý:
    # conn = get_db_connection()
    # cursor = conn.cursor(dictionary=True)
    # cursor.execute("SELECT id, fullname, student_code FROM students")
    # rows = cursor.fetchall()
    # cursor.close(); conn.close()
    # return jsonify(rows)
    return jsonify({"message": "TODO: Việt implement /api/student"}), 501
