from flask import Blueprint, jsonify, request, render_template_string
from .database import get_db_connection
from . import oidc
from werkzeug.security import generate_password_hash

api_bp = Blueprint('api', __name__)

# Template HTML đơn giản cho browser
_STUDENT_HTML = """<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<title>API — Danh sách sinh viên</title>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-900 text-white p-8 font-mono">
<div class="max-w-4xl mx-auto">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-bold text-green-400">GET /api/student</h1>
    <span class="text-xs text-slate-400">Content-Type: application/json</span>
  </div>
  <div class="bg-slate-800 rounded-xl p-4 mb-6 text-xs text-slate-400">
    <span class="text-yellow-400">curl</span> http://localhost:8088/api/student
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    {% for s in students %}
    <div class="bg-slate-800 rounded-xl p-5 border border-slate-700 hover:border-green-500 transition">
      <div class="text-green-400 text-xs font-bold mb-2">{{ loop.index }}.</div>
      <div class="text-white font-bold text-lg mb-1">{{ s.name }}</div>
      <div class="text-slate-400 text-xs mb-3">MSSV: {{ s.id }}</div>
      <div class="text-slate-300 text-xs">📚 {{ s.major }}</div>
    </div>
    {% endfor %}
  </div>
  <div class="mt-8 bg-slate-800 rounded-xl p-4">
    <div class="text-green-400 text-xs mb-2">// JSON response</div>
    <pre class="text-slate-300 text-xs overflow-auto">{{ json_data }}</pre>
  </div>
  <div class="mt-4 text-center">
    <a href="/" class="text-orange-400 hover:text-orange-300 text-sm">← Về trang chủ</a>
  </div>
</div>
</body>
</html>"""


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

        # Content Negotiation: browser nhận HTML, curl/API client nhận JSON
        accept = request.headers.get('Accept', '')
        if 'text/html' in accept and 'application/json' not in accept:
            import json
            return render_template_string(
                _STUDENT_HTML,
                students=students,
                json_data=json.dumps(students, ensure_ascii=False, indent=2)
            )
        return jsonify(students)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/student/secure', methods=['GET'])
@oidc.accept_token()
def get_students_secure():
    return get_students()
