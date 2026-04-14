/**
 * auth.js — SSO tập trung qua Keycloak + Redis
 *
 * Flow:
 *   1. Keycloak xác thực user (redirect-based OIDC)
 *   2. Sau khi có token → gọi POST /api/auth/login để đăng ký vào Redis
 *   3. Token lưu vào localStorage (key: mc_access_token)
 *   4. Mọi trang include file này đều tự động:
 *      - Kiểm tra token còn hạn qua /api/auth/me
 *      - Hiển thị tên user + nút logout trên navbar
 *      - Cung cấp hàm getToken() cho các trang dùng API
 */

const KC_CONFIG = {
    url: window.location.origin + '/auth',
    realm: 'realm_52300267',
    clientId: 'flask-app',
};

const TOKEN_KEY = 'mc_access_token';
const REFRESH_KEY = 'mc_refresh_token';

// Khởi tạo Keycloak instance
const _kc = new Keycloak(KC_CONFIG);

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Khởi động SSO. Gọi ở đầu mỗi trang.
 * @param {object} opts
 *   - onLogin(session)  : callback khi đã xác thực xong, nhận {username, roles, ttl_remaining}
 *   - onLogout()        : callback khi chưa đăng nhập / đã logout
 *   - required (bool)   : nếu true → redirect sang Keycloak nếu chưa login (default: false)
 */
async function initAuth({ onLogin, onLogout, required = false } = {}) {
    // Thử verify token đang có trong localStorage trước (tránh redirect không cần thiết)
    const saved = localStorage.getItem(TOKEN_KEY);
    if (saved) {
        const session = await _verifyWithServer(saved);
        if (session) {
            _renderNavbar(session);
            onLogin && onLogin(session);
            _scheduleRefresh();
            return session;
        }
        // Token hết hạn hoặc bị revoke → xóa
        _clearLocal();
    }

    // Khởi động Keycloak
    try {
        const authenticated = await _kc.init({
            onLoad: required ? 'login-required' : 'check-sso',
            silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
            checkLoginIframe: false,
        });

        if (authenticated) {
            // Đăng ký token vào Redis
            const session = await _registerToken(_kc.token, _kc.refreshToken);
            if (session) {
                _renderNavbar(session);
                onLogin && onLogin(session);
                _scheduleRefresh();
                return session;
            }
        }
    } catch (e) {
        console.warn('[auth.js] Keycloak init error:', e);
    }

    onLogout && onLogout();
    return null;
}

/** Lấy token hiện tại từ localStorage */
function getToken() {
    return localStorage.getItem(TOKEN_KEY);
}

/** Lấy header Authorization sẵn sàng dùng cho fetch */
function authHeader() {
    const t = getToken();
    return t ? { 'Authorization': 'Bearer ' + t } : {};
}

/** Đăng xuất: revoke Redis + Keycloak logout */
async function logout() {
    const token = getToken();
    if (token) {
        await fetch('/api/auth/logout', {
            method: 'POST',
            headers: { 'Authorization': 'Bearer ' + token },
        }).catch(() => { });
    }
    _clearLocal();
    _kc.logout({ redirectUri: window.location.origin });
}

// ── Internal helpers ──────────────────────────────────────────────────────────

async function _registerToken(accessToken, refreshToken) {
    try {
        const res = await fetch('/api/auth/login-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ access_token: accessToken, refresh_token: refreshToken || '' }),
        });
        if (!res.ok) return null;
        const data = await res.json();
        localStorage.setItem(TOKEN_KEY, accessToken);
        if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
        return data;
    } catch (e) {
        console.warn('[auth.js] _registerToken error:', e);
        return null;
    }
}

async function _verifyWithServer(token) {
    try {
        const res = await fetch('/api/auth/me', {
            headers: { 'Authorization': 'Bearer ' + token },
        });
        if (!res.ok) return null;
        return await res.json();
    } catch {
        return null;
    }
}

function _clearLocal() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_KEY);
}

function _renderNavbar(session) {
    // Tìm các element theo id chuẩn (dùng chung cho mọi trang)
    const userEl = document.getElementById('kc-user');
    const btnEl = document.getElementById('kc-btn');
    const roleEl = document.getElementById('kc-roles');

    if (userEl) {
        userEl.textContent = '👤 ' + session.username;
        userEl.classList.remove('hidden');
    }
    if (btnEl) {
        btnEl.textContent = 'Đăng xuất';
        btnEl.onclick = logout;
        btnEl.classList.remove('hidden');
        btnEl.className = btnEl.className.replace('bg-orange-500', 'bg-red-500')
            .replace('hover:bg-orange-600', 'hover:bg-red-600');
    }
    if (roleEl) {
        const isAdmin = session.roles.includes('admin');
        const isEditor = session.roles.includes('editor');
        roleEl.textContent = isAdmin ? '🔴 Admin' : isEditor ? '🟡 Editor' : '🟢 Viewer';
        roleEl.classList.remove('hidden');
    }
}

// Tự động refresh token trước khi hết hạn (5 phút trước exp)
function _scheduleRefresh() {
    _kc.onTokenExpired = async () => {
        try {
            const refreshed = await _kc.updateToken(300);
            if (refreshed) {
                await _registerToken(_kc.token, _kc.refreshToken);
            }
        } catch {
            _clearLocal();
            window.location.reload();
        }
    };
}
