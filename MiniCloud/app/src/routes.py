import json
import requests as http_requests
from flask import Blueprint, jsonify, request, render_template_string
from .database import get_db_connection
from . import oidc
from werkzeug.security import generate_password_hash
from functools import wraps
from .token_store import store_token, verify_token, revoke_token, list_active_sessions
import os

api_bp = Blueprint('api', __name__)

# ── Keycloak token endpoint ───────────────────────────────────────────────────

def _kc_token_url():
    return os.environ.get(
        'KC_TOKEN_URL',
        'http://auth:8080/auth/realms/realm_52300267/protocol/openid-connect/token'
    )

def _kc_client_id():
    return os.environ.get('KC_CLIENT_ID', 'flask-app')

def _kc_client_secret():
    return os.environ.get('KC_CLIENT_SECRET', 'public')


# ── Role helpers (dùng Redis) ─────────────────────────────────────────────────

def _get_bearer_token() -> str | None:
    """Lấy token từ Authorization header hoặc cookie mc_token."""
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return auth[7:]
    # Fallback: đọc từ cookie (browser)
    return request.cookies.get('mc_token', '').strip() or None


def require_role(*roles):
    """Decorator: kiểm tra token trong Redis VÀ có đủ role."""
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            token = _get_bearer_token()
            if not token:
                return jsonify({"error": "Unauthorized", "detail": "Thiếu Bearer Token"}), 401

            session = verify_token(token)
            if not session:
                return jsonify({
                    "error": "Unauthorized",
                    "detail": "Token không hợp lệ hoặc chưa đăng nhập qua /api/auth/login"
                }), 401

            if not any(r in session['roles'] for r in roles):
                return jsonify({
                    "error": "Forbidden",
                    "detail": f"Yêu cầu một trong các role: {list(roles)}. Role hiện tại: {session['roles']}"
                }), 403

            return f(*args, **kwargs)
        return wrapped
    return decorator


# ── HTML template ─────────────────────────────────────────────────────────────

_TABLE_HTML = """<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{ table_name | upper }} — MiniCloud API</title>
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
  * { font-family: 'Plus Jakarta Sans', sans-serif; }
  pre { white-space: pre-wrap; word-break: break-all; font-family: 'Courier New', monospace; }
  .fade-in { animation: fadeIn .25s ease; }
  @keyframes fadeIn { from { opacity:0; transform:translateY(6px); } to { opacity:1; transform:none; } }
  tr:hover td { background: #f8fafc; }
  .badge { display:inline-flex; align-items:center; gap:4px; font-size:11px; font-weight:700; padding:2px 10px; border-radius:999px; }
</style>
</head>
<body class="bg-gray-50 min-h-screen">

<!-- Top navbar -->
<nav class="bg-white border-b border-gray-200 sticky top-0 z-40 shadow-sm">
  <div class="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
    <div class="flex items-center gap-3">
      <a href="/" class="flex items-center gap-2 text-gray-800 hover:text-orange-500 transition font-bold text-lg">
        <div class="w-7 h-7 bg-orange-500 rounded-lg flex items-center justify-center text-white text-sm font-black">M</div>
        MiniCloud
      </a>
      <span class="text-gray-300">/</span>
      <span class="text-gray-500 text-sm font-medium">API Explorer</span>
      <span class="text-gray-300">/</span>
      <span class="text-orange-500 text-sm font-semibold">{{ table_name }}</span>
    </div>
    <div class="flex items-center gap-3" id="navRight">
      <span id="navUser" class="hidden items-center gap-2 text-sm font-semibold text-gray-700">
        <span class="w-7 h-7 bg-green-100 text-green-700 rounded-full flex items-center justify-center text-xs font-bold" id="navAvatar">?</span>
        <span id="navUsername"></span>
        <span id="navRole" class="badge"></span>
        <span id="navTTL" class="text-xs text-gray-400 font-normal"></span>
      </span>
      <button id="navLoginBtn" onclick="toggleLoginPanel()"
        class="bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold px-4 py-1.5 rounded-lg transition shadow-sm">
        Đăng nhập
      </button>
      <button id="navLogoutBtn" onclick="doLogout()"
        class="hidden bg-red-50 hover:bg-red-100 text-red-600 text-sm font-semibold px-4 py-1.5 rounded-lg transition border border-red-200">
        Đăng xuất
      </button>
    </div>
  </div>
</nav>

<!-- Login panel overlay -->
<div id="loginPanel" class="hidden fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
  <div class="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-sm mx-4 fade-in">
    <div class="flex items-center gap-3 mb-6">
      <div class="w-10 h-10 bg-orange-500 rounded-xl flex items-center justify-center text-white font-black text-lg">M</div>
      <div>
        <h2 class="font-bold text-gray-900 text-lg">Đăng nhập</h2>
        <p class="text-xs text-gray-400">Xác thực qua Keycloak + Redis</p>
      </div>
    </div>
    <div class="space-y-3 mb-4">
      <input id="loginUser" type="text" placeholder="Username"
        class="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 focus:border-orange-400 transition" />
      <input id="loginPass" type="password" placeholder="Password"
        class="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-orange-300 focus:border-orange-400 transition"
        onkeydown="if(event.key==='Enter') doLogin()" />
    </div>
    <p id="loginMsg" class="text-xs text-red-500 mb-3 hidden"></p>
    <div class="flex gap-2">
      <button onclick="doLogin()" id="loginSubmitBtn"
        class="flex-1 bg-orange-500 hover:bg-orange-600 text-white font-bold py-2.5 rounded-xl transition shadow-sm">
        Đăng nhập
      </button>
      <button onclick="toggleLoginPanel()"
        class="px-4 bg-gray-100 hover:bg-gray-200 text-gray-600 font-semibold rounded-xl transition">
        Huỷ
      </button>
    </div>
  </div>
</div>

<!-- Edit modal -->
<div id="editModal" class="hidden fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
  <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md mx-4 fade-in">
    <div class="flex items-center justify-between mb-5">
      <h2 class="font-bold text-gray-900 text-lg">✏️ Chỉnh sửa bản ghi</h2>
      <button onclick="closeEdit()" class="text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
    </div>
    <div id="editFields" class="space-y-3 mb-5"></div>
    <div class="flex gap-2">
      <button onclick="submitEdit()"
        class="flex-1 bg-amber-500 hover:bg-amber-600 text-white font-bold py-2.5 rounded-xl transition shadow-sm">
        Lưu thay đổi
      </button>
      <button onclick="closeEdit()"
        class="px-5 bg-gray-100 hover:bg-gray-200 text-gray-600 font-semibold rounded-xl transition">
        Huỷ
      </button>
    </div>
    <p id="editMsg" class="text-xs mt-2 text-gray-400"></p>
  </div>
</div>

<div class="max-w-7xl mx-auto px-6 py-8">

  <!-- Page header -->
  <div class="mb-6">
    <div class="flex items-center gap-3 mb-2">
      <span class="badge bg-green-100 text-green-700 border border-green-200">GET</span>
      <h1 class="text-2xl font-extrabold text-gray-900 font-mono">{{ endpoint }}</h1>
    </div>
    <div class="flex items-center gap-4 text-sm text-gray-500">
      <span>📦 <strong class="text-gray-700">{{ rows|length }}</strong> bản ghi</span>
      <span>🗄️ DB: <strong class="text-blue-600">{{ db_name }}</strong></span>
      <span>📋 Bảng: <strong class="text-orange-500">{{ table_name }}</strong></span>
    </div>
  </div>

  <!-- Add form -->
  <div id="addSection" class="hidden bg-white rounded-2xl border border-gray-200 shadow-sm p-6 mb-6 fade-in">
    <div class="flex items-center gap-2 mb-4">
      <div class="w-8 h-8 bg-green-100 text-green-600 rounded-lg flex items-center justify-center font-bold">+</div>
      <h2 class="font-bold text-gray-800">Thêm bản ghi mới</h2>
    </div>
    <div id="addFields" class="grid grid-cols-2 gap-4 mb-4"></div>
    <div class="flex items-center gap-3">
      <button onclick="submitAdd()"
        class="bg-green-500 hover:bg-green-600 text-white font-bold px-6 py-2 rounded-xl transition shadow-sm">
        ➕ Thêm
      </button>
      <span id="addMsg" class="text-sm text-gray-500"></span>
    </div>
  </div>

  {% if rows %}
  <!-- Table card -->
  <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mb-6">
    <!-- Table toolbar -->
    <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 6h18M3 14h18M3 18h18"/></svg>
        <span class="text-sm font-semibold text-gray-600">Dữ liệu bảng <span class="text-orange-500">{{ table_name }}</span></span>
      </div>
      <div class="flex items-center gap-2">
        <input id="searchInput" oninput="filterTable()" placeholder="Tìm kiếm..."
          class="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-orange-200 w-48 transition" />
        <span class="text-xs text-gray-400 bg-gray-100 px-2 py-1 rounded-lg font-mono">{{ rows|length }} rows</span>
      </div>
    </div>
    <div class="overflow-x-auto">
      <table class="w-full text-sm" id="dataTable">
        <thead class="bg-gray-50">
          <tr>
            {% for col in columns %}
            <th class="text-left px-5 py-3 text-gray-500 font-semibold uppercase text-xs tracking-wider border-b border-gray-100">{{ col }}</th>
            {% endfor %}
            <th id="actionHeader" class="hidden text-left px-5 py-3 text-gray-500 font-semibold uppercase text-xs tracking-wider border-b border-gray-100">Thao tác</th>
          </tr>
        </thead>
        <tbody id="tableBody" class="divide-y divide-gray-50">
          {% for row in rows %}
          <tr class="transition-colors" data-row='{{ row | tojson }}'>
            {% for col in columns %}
            <td class="px-5 py-3.5 text-gray-700">
              {% if row[col] is none %}
                <span class="text-gray-300 italic text-xs">null</span>
              {% else %}
                <span class="font-medium">{{ row[col] }}</span>
              {% endif %}
            </td>
            {% endfor %}
            <td class="action-cell hidden px-5 py-3.5">
              <div class="flex gap-1.5">
                <button class="edit-btn flex items-center gap-1 bg-amber-50 hover:bg-amber-100 text-amber-600 border border-amber-200 text-xs font-semibold px-3 py-1.5 rounded-lg transition"
                  onclick="openEdit(this)">
                  ✏️ Sửa
                </button>
                <button class="delete-btn hidden flex items-center gap-1 bg-red-50 hover:bg-red-100 text-red-600 border border-red-200 text-xs font-semibold px-3 py-1.5 rounded-lg transition"
                  onclick="doDelete(this)">
                  🗑️ Xóa
                </button>
              </div>
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>

  <!-- JSON preview -->
  <details class="bg-white rounded-2xl border border-gray-200 shadow-sm">
    <summary class="px-6 py-4 text-sm font-semibold text-gray-600 cursor-pointer hover:text-gray-900 transition select-none flex items-center gap-2">
      <span class="text-green-500 font-mono text-base">{ }</span>
      Xem JSON response thô
      <span class="ml-auto text-xs text-gray-400 font-normal">{{ rows|length }} items</span>
    </summary>
    <div class="px-6 pb-5 border-t border-gray-100">
      <pre class="text-gray-600 text-xs mt-4 leading-relaxed bg-gray-50 rounded-xl p-4 overflow-auto max-h-96">{{ json_data }}</pre>
    </div>
  </details>

  {% else %}
  <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-16 text-center">
    <div class="text-5xl mb-4">📭</div>
    <p class="text-gray-400 font-medium">Bảng trống hoặc không tìm thấy dữ liệu.</p>
  </div>
  {% endif %}

</div>

<script>
const ENDPOINT = "{{ endpoint }}";
const COLUMNS  = {{ columns | tojson }};
const PK       = COLUMNS[0];
const PK_AUTO  = {{ 'true' if pk_auto else 'false' }};  // true = PK auto-increment, ẩn khỏi form thêm
let currentToken = null;
let currentRoles = [];
let editingRow   = null;
let _ttlTimer    = null;

// ── Khởi động ─────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', async () => {
  // Thử cookie trước (đã đăng nhập từ trang chủ)
  const cookieToken = getCookie('mc_token');
  const savedToken  = localStorage.getItem('mc_access_token');
  const token = cookieToken || savedToken;
  if (token) await verifyAndShow(token);
});

function getCookie(name) {
  const m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
  return m ? decodeURIComponent(m[1]) : null;
}

// ── Login panel ───────────────────────────────────────────────────────────
function toggleLoginPanel() {
  document.getElementById('loginPanel').classList.toggle('hidden');
  document.getElementById('loginMsg').classList.add('hidden');
}

async function doLogin() {
  const username = document.getElementById('loginUser').value.trim();
  const password = document.getElementById('loginPass').value.trim();
  const msg = document.getElementById('loginMsg');
  const btn = document.getElementById('loginSubmitBtn');
  if (!username || !password) { msg.textContent = 'Vui lòng nhập đủ thông tin.'; msg.classList.remove('hidden'); return; }
  btn.textContent = 'Đang xác thực...'; btn.disabled = true;
  try {
    const res = await fetch('/api/auth/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    if (res.ok) {
      localStorage.setItem('mc_access_token', data.access_token);
      document.cookie = `mc_token=${data.access_token}; path=/; max-age=${data.expires_in}; SameSite=Lax`;
      toggleLoginPanel();
      await verifyAndShow(data.access_token);
    } else {
      msg.textContent = data.detail || data.error || 'Đăng nhập thất bại.';
      msg.classList.remove('hidden');
    }
  } catch(e) { msg.textContent = 'Không kết nối được server.'; msg.classList.remove('hidden'); }
  btn.textContent = 'Đăng nhập'; btn.disabled = false;
}

async function doLogout() {
  const token = currentToken || localStorage.getItem('mc_access_token');
  if (token) {
    await fetch('/api/auth/logout', { method: 'POST', headers: { 'Authorization': 'Bearer ' + token } }).catch(()=>{});
    localStorage.removeItem('mc_access_token');
    document.cookie = 'mc_token=; path=/; max-age=0';
  }
  location.reload();
}

async function verifyAndShow(token) {
  try {
    const res = await fetch('/api/auth/me', { headers: { 'Authorization': 'Bearer ' + token } });
    if (!res.ok) { localStorage.removeItem('mc_access_token'); return; }
    const data = await res.json();
    currentToken = token;
    currentRoles = data.roles || [];
    showNavUser(data);
    const isEditor = currentRoles.includes('editor') || currentRoles.includes('admin');
    const isAdmin  = currentRoles.includes('admin');
    if (isEditor) showCRUD(isAdmin);
  } catch(e) {}
}

function showNavUser(data) {
  const isAdmin  = data.roles.includes('admin');
  const isEditor = data.roles.includes('editor');
  document.getElementById('navLoginBtn').classList.add('hidden');
  document.getElementById('navLogoutBtn').classList.remove('hidden');
  const navUser = document.getElementById('navUser');
  navUser.classList.remove('hidden'); navUser.classList.add('flex');
  document.getElementById('navAvatar').textContent = data.username[0].toUpperCase();
  document.getElementById('navUsername').textContent = data.username;
  const roleEl = document.getElementById('navRole');
  if (isAdmin)       { roleEl.textContent = 'Admin';  roleEl.className = 'badge bg-red-100 text-red-700 border border-red-200'; }
  else if (isEditor) { roleEl.textContent = 'Editor'; roleEl.className = 'badge bg-amber-100 text-amber-700 border border-amber-200'; }
  else               { roleEl.textContent = 'Viewer'; roleEl.className = 'badge bg-blue-100 text-blue-700 border border-blue-200'; }
  // TTL countdown
  let ttl = data.ttl_remaining;
  clearInterval(_ttlTimer);
  const ttlEl = document.getElementById('navTTL');
  const tick = () => {
    if (ttl <= 0) { ttlEl.textContent = '⚠️ Hết hạn'; ttlEl.className = 'text-xs text-red-500 font-semibold'; clearInterval(_ttlTimer); return; }
    ttlEl.textContent = `⏱ ${Math.floor(ttl/60)}p${ttl%60}s`;
    ttl--;
  };
  tick(); _ttlTimer = setInterval(tick, 1000);
}

// ── Search ────────────────────────────────────────────────────────────────
function filterTable() {
  const q = document.getElementById('searchInput').value.toLowerCase();
  document.querySelectorAll('#tableBody tr').forEach(tr => {
    tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none';
  });
}

// ── CRUD UI ───────────────────────────────────────────────────────────────
function showCRUD(canDelete) {
  document.getElementById('actionHeader').classList.remove('hidden');
  document.querySelectorAll('.action-cell').forEach(td => td.classList.remove('hidden'));
  if (canDelete) document.querySelectorAll('.delete-btn').forEach(btn => btn.classList.remove('hidden'));
  buildAddFields();
  document.getElementById('addSection').classList.remove('hidden');
}

function buildAddFields() {
  const c = document.getElementById('addFields');
  c.innerHTML = '';
  // Nếu PK_AUTO=true → bỏ qua cột PK (auto-increment)
  // Nếu PK_AUTO=false → hiện tất cả kể cả PK (user phải nhập)
  const cols = PK_AUTO ? COLUMNS.slice(1) : COLUMNS;
  cols.forEach(col => {
    const isPK = col === PK;
    c.innerHTML += `<div>
      <label class="text-xs font-semibold text-gray-500 block mb-1 uppercase tracking-wide">
        ${col}${isPK ? ' <span class="text-orange-500 normal-case font-normal">(bắt buộc)</span>' : ''}
      </label>
      <input id="add_${col}" type="text" placeholder="Nhập ${col}..."
        class="w-full border ${isPK ? 'border-orange-300 focus:ring-orange-200 focus:border-orange-400' : 'border-gray-200 focus:ring-green-200 focus:border-green-400'} rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 transition" />
    </div>`;
  });
}

async function submitAdd() {
  const cols = PK_AUTO ? COLUMNS.slice(1) : COLUMNS;
  const body = {};
  cols.forEach(col => { body[col] = document.getElementById('add_' + col).value; });
  const msg = document.getElementById('addMsg');
  const token = currentToken || localStorage.getItem('mc_access_token') || getCookie('mc_token');
  if (!token) { msg.textContent = '❌ Chưa đăng nhập'; msg.className = 'text-sm text-red-500'; return; }
  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body: JSON.stringify(body)
    });
    const data = await res.json();
    if (res.ok) { msg.textContent = '✅ Đã thêm thành công!'; msg.className = 'text-sm text-green-600 font-semibold'; setTimeout(() => location.reload(), 800); }
    else         { msg.textContent = '❌ ' + (data.detail || data.error); msg.className = 'text-sm text-red-500'; }
  } catch(e) { msg.textContent = '❌ ' + e; msg.className = 'text-sm text-red-500'; }
}

function openEdit(btn) {
  const tr = btn.closest('tr');
  editingRow = JSON.parse(tr.dataset.row);
  const c = document.getElementById('editFields');
  c.innerHTML = '';
  COLUMNS.forEach(col => {
    const isPK = col === PK;
    c.innerHTML += `<div>
      <label class="text-xs font-semibold text-gray-500 block mb-1 uppercase tracking-wide">${col}${isPK?' <span class="text-orange-400">(PK)</span>':''}</label>
      <input id="edit_${col}" type="text" value="${editingRow[col] ?? ''}" ${isPK?'readonly':''}
        class="w-full border ${isPK?'border-gray-100 bg-gray-50 text-gray-400':'border-gray-200 focus:ring-2 focus:ring-amber-200 focus:border-amber-400'} rounded-xl px-3 py-2 text-sm focus:outline-none transition" />
    </div>`;
  });
  document.getElementById('editModal').classList.remove('hidden');
}

function closeEdit() { document.getElementById('editModal').classList.add('hidden'); }

async function submitEdit() {
  const pkVal = editingRow[PK];
  const body  = {};
  COLUMNS.slice(1).forEach(col => { body[col] = document.getElementById('edit_' + col).value; });
  const msg = document.getElementById('editMsg');
  const token = currentToken || localStorage.getItem('mc_access_token') || getCookie('mc_token');
  if (!token) { msg.textContent = '❌ Chưa đăng nhập'; msg.className = 'text-xs mt-2 text-red-500'; return; }
  try {
    const res = await fetch(`${ENDPOINT}/${pkVal}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body: JSON.stringify(body)
    });
    const data = await res.json();
    if (res.ok) { msg.textContent = '✅ Đã cập nhật!'; msg.className = 'text-xs mt-2 text-green-600 font-semibold'; setTimeout(() => location.reload(), 700); }
    else         { msg.textContent = '❌ ' + (data.detail || data.error); msg.className = 'text-xs mt-2 text-red-500'; }
  } catch(e) { msg.textContent = '❌ ' + e; msg.className = 'text-xs mt-2 text-red-500'; }
}

async function doDelete(btn) {
  const row = JSON.parse(btn.closest('tr').dataset.row);
  const pkVal = row[PK];
  const token = currentToken || localStorage.getItem('mc_access_token') || getCookie('mc_token');
  if (!token) { alert('❌ Chưa đăng nhập'); return; }
  if (!confirm(`Xác nhận xóa bản ghi ${PK} = "${pkVal}"?`)) return;
  try {
    const res = await fetch(`${ENDPOINT}/${pkVal}`, {
      method: 'DELETE', headers: { 'Authorization': 'Bearer ' + token }
    });
    if (res.ok) {
      const tr = btn.closest('tr');
      tr.style.opacity = '0'; tr.style.transition = 'opacity .3s';
      setTimeout(() => tr.remove(), 300);
    } else {
      const data = await res.json();
      alert('❌ ' + (data.detail || data.error));
    }
  } catch(e) { alert('❌ ' + e); }
}
</script>
</body>
</html>"""


def _render_table(rows, endpoint, db_name, table_name, pk_auto=True):
    """Render HTML table hoặc JSON tùy Accept header.
    pk_auto=True  → PK là auto-increment, ẩn khỏi form thêm (vd: notes.id)
    pk_auto=False → PK do user nhập (vd: students.student_id)
    """
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
            pk_auto=pk_auto,
            json_data=json.dumps(rows, ensure_ascii=False, indent=2, default=str)
        )
    return jsonify(rows)


# ── Endpoints ─────────────────────────────────────────────────────────────────

@api_bp.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Modular App Server!"})


@api_bp.route('/api/register_demo', methods=['GET'])
def register_demo():
    mat_khau_da_bam = generate_password_hash("mat_khau_bi_mat_123")
    return jsonify({"thong_bao": "Sẵn sàng lưu vào DB", "hash_se_luu": mat_khau_da_bam})


# ── Auth endpoints ────────────────────────────────────────────────────────────

@api_bp.route('/api/auth/login', methods=['POST'])
def login():
    """
    Đăng nhập qua Keycloak bằng username/password, lưu token vào Redis.
    Body: { "username": "...", "password": "..." }
    """
    data = request.get_json(force=True) or {}
    username = data.get('username', '').strip()
    password = data.get('password', '').strip()
    if not username or not password:
        return jsonify({"error": "Bad Request", "detail": "Cần 'username' và 'password'"}), 400

    try:
        resp = http_requests.post(_kc_token_url(), data={
            'grant_type': 'password',
            'client_id': _kc_client_id(),
            'client_secret': _kc_client_secret(),
            'username': username,
            'password': password,
        }, timeout=10)
    except Exception as e:
        return jsonify({"error": "Keycloak không phản hồi", "detail": str(e)}), 503

    if resp.status_code != 200:
        return jsonify({
            "error": "Đăng nhập thất bại",
            "detail": resp.json().get('error_description', resp.text)
        }), 401

    kc_data = resp.json()
    access_token = kc_data.get('access_token')
    refresh_token = kc_data.get('refresh_token')

    try:
        session = store_token(access_token, refresh_token)
    except ValueError as e:
        return jsonify({"error": "Token lỗi", "detail": str(e)}), 400

    return jsonify({
        "message": "Đăng nhập thành công",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "username": session['username'],
        "roles": session['roles'],
        "expires_in": session['ttl'],
    })


@api_bp.route('/api/auth/login-token', methods=['POST'])
def login_token():
    """
    Nhận access_token đã có từ Keycloak JS (OIDC flow phía browser),
    đăng ký vào Redis. Dùng bởi auth.js trên web frontend.
    Body: { "access_token": "...", "refresh_token": "..." }
    """
    data = request.get_json(force=True) or {}
    access_token = data.get('access_token', '').strip()
    refresh_token = data.get('refresh_token', '').strip()
    if not access_token:
        return jsonify({"error": "Bad Request", "detail": "Cần 'access_token'"}), 400
    try:
        session = store_token(access_token, refresh_token or None)
    except ValueError as e:
        return jsonify({"error": "Token lỗi", "detail": str(e)}), 400
    return jsonify({
        "message": "Token đã được đăng ký",
        "username": session['username'],
        "roles": session['roles'],
        "ttl_remaining": session['ttl'],
    })


@api_bp.route('/api/auth/logout', methods=['POST'])
def logout():
    """Thu hồi token khỏi Redis ngay lập tức."""
    token = _get_bearer_token()
    if not token:
        return jsonify({"error": "Unauthorized", "detail": "Thiếu Bearer Token"}), 401
    revoked = revoke_token(token)
    if revoked:
        return jsonify({"message": "Đã đăng xuất, token bị thu hồi"})
    return jsonify({"error": "Token không tồn tại trong hệ thống"}), 404


@api_bp.route('/api/auth/me', methods=['GET'])
def me():
    """Kiểm tra token hiện tại còn hạn không và xem thông tin session."""
    token = _get_bearer_token()
    if not token:
        return jsonify({"error": "Unauthorized", "detail": "Thiếu Bearer Token"}), 401
    session = verify_token(token)
    if not session:
        return jsonify({"error": "Token không hợp lệ hoặc đã hết hạn"}), 401
    return jsonify(session)


@api_bp.route('/api/auth/me-cookie', methods=['GET'])
def me_cookie():
    """
    Dùng cho Nginx auth_request — đọc token từ cookie mc_token
    hoặc Authorization header (ưu tiên header).
    Trả 200 nếu hợp lệ, 401 nếu không.
    """
    # Ưu tiên Authorization header (API client)
    token = _get_bearer_token()
    # Fallback: đọc từ cookie (browser)
    if not token:
        token = request.cookies.get('mc_token', '').strip()
    if not token:
        return '', 401
    session = verify_token(token)
    if not session:
        return '', 401
    return '', 200


@api_bp.route('/api/auth/sessions', methods=['GET'])
@require_role('admin')
def active_sessions():
    """[Admin only] Xem tất cả sessions đang active trong Redis."""
    return jsonify(list_active_sessions())


# ── /api/student ──────────────────────────────────────────────────────────────

@api_bp.route('/api/student', methods=['GET'])
def get_students():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT student_id as id, fullname as name, major FROM students")
        rows = cursor.fetchall()
        cursor.close(); conn.close()
        return _render_table(rows, '/api/student', 'studentdb', 'students', pk_auto=False)
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/student', methods=['POST'])
@require_role('editor', 'admin')
def add_student():
    data = request.get_json(force=True) or {}
    required = ['id', 'name', 'major']
    if not all(k in data for k in required):
        return jsonify({"error": "Bad Request", "detail": f"Cần các trường: {required}"}), 400
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO students (student_id, fullname, major) VALUES (%s, %s, %s)",
            (data['id'], data['name'], data['major'])
        )
        conn.commit(); cursor.close(); conn.close()
        return jsonify({"message": "Đã thêm sinh viên", "id": data['id']}), 201
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/student/<string:student_id>', methods=['PUT'])
@require_role('editor', 'admin')
def update_student(student_id):
    data = request.get_json(force=True) or {}
    fields = {k: v for k, v in data.items() if k in ('name', 'major')}
    if not fields:
        return jsonify({"error": "Bad Request", "detail": "Không có trường hợp lệ để cập nhật (name, major)"}), 400
    col_map = {'name': 'fullname', 'major': 'major'}
    set_clause = ', '.join(f"{col_map[k]}=%s" for k in fields)
    values = list(fields.values()) + [student_id]
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(f"UPDATE students SET {set_clause} WHERE student_id=%s", values)
        if cursor.rowcount == 0:
            cursor.close(); conn.close()
            return jsonify({"error": "Not Found", "detail": f"Không tìm thấy student_id={student_id}"}), 404
        conn.commit(); cursor.close(); conn.close()
        return jsonify({"message": "Đã cập nhật", "student_id": student_id})
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/student/<string:student_id>', methods=['DELETE'])
@require_role('admin')
def delete_student(student_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM students WHERE student_id=%s", (student_id,))
        if cursor.rowcount == 0:
            cursor.close(); conn.close()
            return jsonify({"error": "Not Found", "detail": f"Không tìm thấy student_id={student_id}"}), 404
        conn.commit(); cursor.close(); conn.close()
        return jsonify({"message": "Đã xóa", "student_id": student_id})
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── /api/notes ────────────────────────────────────────────────────────────────

@api_bp.route('/api/notes', methods=['GET'])
def get_notes():
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


@api_bp.route('/api/notes', methods=['POST'])
@require_role('editor', 'admin')
def add_note():
    data = request.get_json(force=True) or {}
    if 'title' not in data:
        return jsonify({"error": "Bad Request", "detail": "Cần trường 'title'"}), 400
    try:
        conn = get_db_connection(database='minicloud')
        cursor = conn.cursor()
        cursor.execute("INSERT INTO notes (title) VALUES (%s)", (data['title'],))
        conn.commit()
        new_id = cursor.lastrowid
        cursor.close(); conn.close()
        return jsonify({"message": "Đã thêm note", "id": new_id}), 201
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/notes/<int:note_id>', methods=['PUT'])
@require_role('editor', 'admin')
def update_note(note_id):
    data = request.get_json(force=True) or {}
    if 'title' not in data:
        return jsonify({"error": "Bad Request", "detail": "Cần trường 'title'"}), 400
    try:
        conn = get_db_connection(database='minicloud')
        cursor = conn.cursor()
        cursor.execute("UPDATE notes SET title=%s WHERE id=%s", (data['title'], note_id))
        if cursor.rowcount == 0:
            cursor.close(); conn.close()
            return jsonify({"error": "Not Found", "detail": f"Không tìm thấy note id={note_id}"}), 404
        conn.commit(); cursor.close(); conn.close()
        return jsonify({"message": "Đã cập nhật", "id": note_id})
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@api_bp.route('/api/notes/<int:note_id>', methods=['DELETE'])
@require_role('admin')
def delete_note(note_id):
    try:
        conn = get_db_connection(database='minicloud')
        cursor = conn.cursor()
        cursor.execute("DELETE FROM notes WHERE id=%s", (note_id,))
        if cursor.rowcount == 0:
            cursor.close(); conn.close()
            return jsonify({"error": "Not Found", "detail": f"Không tìm thấy note id={note_id}"}), 404
        conn.commit(); cursor.close(); conn.close()
        return jsonify({"message": "Đã xóa", "id": note_id})
    except ConnectionError as e:
        return jsonify({"error": "Service Unavailable", "detail": str(e)}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Secure alias ──────────────────────────────────────────────────────────────

@api_bp.route('/api/student/secure', methods=['GET'])
@oidc.accept_token()
def get_students_secure():
    return get_students()
