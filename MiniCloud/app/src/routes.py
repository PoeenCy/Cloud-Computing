import json
from flask import Blueprint, jsonify, request, render_template_string
from .database import get_db_connection
from . import oidc
from werkzeug.security import generate_password_hash

api_bp = Blueprint('api', __name__)

# ── HTML template dùng chung cho mọi bảng ────────────────────────────────────
_TABLE_HTML = """<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<title>API — {{ endpoint }}</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>
  body { font-family: 'Segoe UI', sans-serif; }
  pre { white-space: pre-wrap; word-break: break-all; }
</style>
</head>
<body class="bg-slate-900 min-h-screen p-6">
<div class="max-w-6xl mx-auto">

  <!-- Header -->
  <div class="flex items-center justify-between mb-6">
    <div>
      <div class="flex items-center gap-3 mb-1">
        <span class="bg-green-500/20 text-green-400 border border-green-500/30 text-xs font-bold px-3 py-1 rounded-full">GET</span>
        <h1 class="text-white font-mono text-xl font-bold">{{ endpoint }}</h1>
      </div>
      <p class="text-slate-400 text-sm">{{ rows|length }} bản ghi • database: <span class="text-cyan-400">{{ db_name }}</span> • bảng: <span class="text-orange-400">{{ table_name }}</span></p>
    </div>
    <a href="/" class="text-slate-400 hover:text-white text-sm transition">← Trang chủ</a>
  </div>

  <!-- Curl hint -->
  <div class="bg-slate-800 rounded-lg px-4 py-3 mb-6 flex items-center gap-3">
    <span class="text-yellow-400 font-mono text-sm">$</span>
    <code class="text-slate-300 font-mono text-sm">curl http://localhost:8088{{ endpoint }}</code>
    <span class="ml-auto text-slate-500 text-xs">→ JSON</span>
  </div>

  {% if rows %}
  <!-- Data Table -->
  <div class="bg-slate-800 rounded-xl overflow-hidden border border-slate-700 mb-6">
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-slate-700">
            {% for col in columns %}
            <th class="text-left px-5 py-3 text-slate-400 font-semibold uppercase text-xs tracking-wider">{{ col }}</th>
            {% endfor %}
          </tr>
        </thead>
        <tbody>
          {% for row in rows %}
          <tr class="border-b border-slate-700/50 hover:bg-slate-700/30 transition">
            {% for col in columns %}
            <td class="px-5 py-3 text-slate-200">
              {% if row[col] is none %}
                <span class="text-slate-500 italic">null</span>
              {% else %}
                {{ row[col] }}
              {% endif %}
            </td>
            {% endfor %}
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>

  <!-- JSON Preview -->
  <details class="bg-slate-800 rounded-xl border border-slate-700">
    <summary class="px-5 py-3 text-slate-400 text-sm cursor-pointer hover:text-white transition select-none">
      <span class="text-green-400 font-mono">{ }</span> Xem JSON response
    </summary>
    <div class="px-5 pb-4">
      <pre class="text-slate-300 text-xs mt-3 leading-relaxed">{{ json_data }}</pre>
    </div>
  </details>

  {% else %}
  <div class="bg-slate-800 rounded-xl p-12 text-center text-slate-500 border border-slate-700">
    Bảng trống hoặc không tìm thấy dữ liệu.
  </div>
  {% endif %}

</div>
</body>
</html>"""


def _render_table(rows, endpoint, db_name, table_name):
    """Render HTML table hoặc JSON tùy Accept header."""
    accept = request.headers.get('Accept', '')
    if 'text/html' in accept and 'application/json' not in accept:
        columns = list(rows[0].keys()) if rows else []
        return render_template_string(
            _TABLE_HTML,
            rows=rows,
            columns=columns,
            endpoint=endpoint,
            db_name=db_name,
            table_name=table_name,
            json_data=json.dumps(rows, ensure_ascii=False, indent=2, default=str)
        )
    return jsonify(rows)


# ── Endpoints cụ thể ──────────────────────────────────────────────────────────

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})


@api_bp.route('/api/register_demo', methods=['GET'])
def register_demo():
    mat_khau_da_bam = generate_password_hash("mat_khau_bi_mat_123")
    return jsonify({"thong_bao": "Sẵn sàng lưu vào DB", "hash_se_luu": mat_khau_da_bam})


@api_bp.route('/api/student', methods=['GET'])
def get_students():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT student_id as id, fullname as name, major FROM students")
        rows = cursor.fetchall()
        cursor.close(); conn.close()
        return _render_table(rows, '/api/student', 'studentdb', 'students')
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/notes', methods=['GET'])
def get_notes():
    """Bảng notes từ database minicloud."""
    try:
        conn = get_db_connection(database='minicloud')
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM notes")
        rows = cursor.fetchall()
        cursor.close(); conn.close()
        return _render_table(rows, '/api/notes', 'minicloud', 'notes')
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/student/secure', methods=['GET'])
@oidc.accept_token()
def get_students_secure():
    return get_students()
