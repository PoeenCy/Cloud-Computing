from flask import Blueprint, jsonify
from .database import get_db_connection

api_bp = Blueprint('api', __name__)

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})

@api_bp.route('/api/student', methods=['GET'])
def get_students():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        # Truy vấn vào thẳng database studentdb
        cursor.execute("SELECT id, student_id, fullname, dob, major FROM studentdb.students")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": str(e)}), 500