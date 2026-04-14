"""
token_store.py — Lưu trữ và kiểm tra token tập trung qua Redis.

Flow:
  1. Client đăng nhập qua POST /api/auth/login
     → Flask lấy token từ Keycloak, lưu vào Redis với TTL = thời gian còn lại của token
  2. Mọi request có Bearer Token:
     → Flask decode JWT lấy jti, tra Redis
     → Nếu không có trong Redis → từ chối (token chưa đăng nhập qua hệ thống hoặc đã logout)
     → Nếu có → trả về payload (roles, username, ...)
  3. Logout: xóa key khỏi Redis → token lập tức vô hiệu dù chưa hết hạn
"""

import os
import json
import time
import redis
import jwt as pyjwt

# ── Kết nối Redis ─────────────────────────────────────────────────────────────

def _get_redis() -> redis.Redis:
    return redis.Redis(
        host=os.environ.get('REDIS_HOST', 'minicloud-redis'),
        port=int(os.environ.get('REDIS_PORT', 6379)),
        password=os.environ.get('REDIS_PASSWORD', 'redis_secret_123'),
        decode_responses=True,
    )


def _token_key(jti: str) -> str:
    return f"token:{jti}"


# ── Lưu token ─────────────────────────────────────────────────────────────────

def store_token(access_token: str, refresh_token: str | None = None) -> dict:
    """
    Decode JWT, lưu payload vào Redis với TTL = thời gian còn lại.
    Trả về payload đã lưu.
    """
    payload = pyjwt.decode(access_token, options={"verify_signature": False})
    jti = payload.get('jti')
    if not jti:
        raise ValueError("Token không có trường 'jti'")

    exp = payload.get('exp', 0)
    ttl = int(exp - time.time())
    if ttl <= 0:
        raise ValueError("Token đã hết hạn")

    data = {
        "access_token": access_token,
        "refresh_token": refresh_token or "",
        "username": payload.get('preferred_username', ''),
        "email": payload.get('email', ''),
        "roles": json.dumps(payload.get('realm_access', {}).get('roles', [])),
        "exp": str(exp),
        "stored_at": str(int(time.time())),
    }

    r = _get_redis()
    r.hset(_token_key(jti), mapping=data)
    r.expire(_token_key(jti), ttl)
    return {**data, "roles": json.loads(data["roles"]), "jti": jti, "ttl": ttl}


# ── Kiểm tra token ────────────────────────────────────────────────────────────

def verify_token(access_token: str) -> dict | None:
    """
    Kiểm tra token có trong Redis không.
    Trả về dict {username, roles, jti, ttl_remaining} hoặc None nếu không hợp lệ.
    """
    try:
        payload = pyjwt.decode(access_token, options={"verify_signature": False})
    except Exception:
        return None

    jti = payload.get('jti')
    if not jti:
        return None

    r = _get_redis()
    key = _token_key(jti)

    if not r.exists(key):
        return None  # chưa đăng nhập qua hệ thống hoặc đã logout

    ttl = r.ttl(key)
    if ttl <= 0:
        return None  # hết hạn

    roles_raw = r.hget(key, 'roles') or '[]'
    return {
        "jti": jti,
        "username": r.hget(key, 'username') or '',
        "email": r.hget(key, 'email') or '',
        "roles": json.loads(roles_raw),
        "ttl_remaining": ttl,
    }


# ── Xóa token (logout) ────────────────────────────────────────────────────────

def revoke_token(access_token: str) -> bool:
    """Xóa token khỏi Redis — logout tức thì."""
    try:
        payload = pyjwt.decode(access_token, options={"verify_signature": False})
        jti = payload.get('jti')
        if not jti:
            return False
        r = _get_redis()
        return bool(r.delete(_token_key(jti)))
    except Exception:
        return False


# ── Liệt kê sessions đang active (admin) ─────────────────────────────────────

def list_active_sessions() -> list[dict]:
    """Trả về danh sách tất cả token đang còn hạn trong Redis."""
    r = _get_redis()
    keys = r.keys("token:*")
    sessions = []
    for key in keys:
        ttl = r.ttl(key)
        if ttl <= 0:
            continue
        data = r.hgetall(key)
        sessions.append({
            "jti": key.replace("token:", ""),
            "username": data.get("username", ""),
            "email": data.get("email", ""),
            "roles": json.loads(data.get("roles", "[]")),
            "ttl_remaining": ttl,
            "stored_at": data.get("stored_at", ""),
        })
    return sorted(sessions, key=lambda x: x["ttl_remaining"], reverse=True)
