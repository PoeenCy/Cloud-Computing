# MinIO SSO Flow Diagram

## 🔐 Luồng xác thực SSO (Single Sign-On)

```mermaid
sequenceDiagram
    participant User as 👤 User Browser
    participant Nginx as 🔀 Nginx Proxy<br/>(10.10.1.10)
    participant Web as 🌐 Web Server<br/>(10.10.1.11)
    participant KC as 🔑 Keycloak<br/>(10.10.1.13)
    participant MinIO as 📦 MinIO Console<br/>(10.10.2.15)

    Note over User,MinIO: Bước 1: Đăng nhập vào Website
    User->>Nginx: GET http://localhost:8088/
    Nginx->>Web: Forward request
    Web-->>User: Hiển thị trang chủ + Login button

    User->>Nginx: POST /api/auth/login<br/>{username, password}
    Nginx->>KC: POST /auth/realms/.../token<br/>(Resource Owner Password Flow)
    KC-->>Nginx: access_token + refresh_token
    Nginx-->>User: Set cookie: mc_token=<access_token>

    Note over User,MinIO: Bước 2: Truy cập MinIO Console
    User->>Nginx: GET http://localhost:8088/minio/
    Nginx->>MinIO: Forward to 10.10.2.15:9001
    MinIO-->>User: Hiển thị MinIO Login Page<br/>- Login with SSO<br/>- Login with credentials

    Note over User,MinIO: Bước 3: Click "Login with SSO"
    User->>MinIO: Click "Login with SSO"
    MinIO->>User: Redirect to Keycloak Authorization URL<br/>http://localhost:8088/auth/realms/.../protocol/openid-connect/auth<br/>?client_id=minio<br/>&redirect_uri=http://localhost:8088/minio/oauth_callback<br/>&response_type=code<br/>&scope=openid profile email

    Note over User,MinIO: Bước 4: Keycloak kiểm tra session
    User->>Nginx: GET /auth/realms/.../auth?...
    Nginx->>KC: Forward request + cookie
    
    alt User đã đăng nhập (có session)
        KC-->>User: Redirect to MinIO callback<br/>http://localhost:8088/minio/oauth_callback?code=<auth_code>
    else User chưa đăng nhập
        KC-->>User: Hiển thị Keycloak Login Page
        User->>KC: POST username + password
        KC-->>User: Redirect to MinIO callback<br/>http://localhost:8088/minio/oauth_callback?code=<auth_code>
    end

    Note over User,MinIO: Bước 5: MinIO đổi code lấy token
    User->>Nginx: GET /minio/oauth_callback?code=<auth_code>
    Nginx->>MinIO: Forward request
    MinIO->>KC: POST /auth/realms/.../token<br/>{code, client_id, client_secret}
    KC-->>MinIO: access_token + id_token
    MinIO->>MinIO: Validate token<br/>Extract username từ preferred_username claim
    MinIO-->>User: Set MinIO session cookie<br/>Redirect to MinIO Console Dashboard

    Note over User,MinIO: ✅ Hoàn tất - User đã đăng nhập MinIO
    User->>Nginx: GET /minio/browser
    Nginx->>MinIO: Forward request + MinIO session cookie
    MinIO-->>User: Hiển thị MinIO Console Dashboard
```

---

## 🔄 Các luồng xác thực

### 1. Website Login (Resource Owner Password Flow)
```
User → Nginx → Keycloak
     ← access_token ←
```

**Đặc điểm:**
- Direct username/password
- Không có redirect
- Token lưu trong cookie `mc_token`

### 2. MinIO SSO (Authorization Code Flow)
```
User → MinIO → Keycloak (Authorization)
     ← auth_code ←
MinIO → Keycloak (Token Exchange)
      ← access_token ←
```

**Đặc điểm:**
- Redirect-based flow
- Secure (code exchange)
- Tận dụng Keycloak session

---

## 🔑 Token Flow

### Access Token Journey

```mermaid
graph LR
    A[Keycloak] -->|Issue| B[access_token]
    B -->|Store in| C[Cookie: mc_token]
    C -->|Send to| D[Nginx]
    D -->|Validate via| E[Flask /api/auth/me-cookie]
    E -->|Check in| F[Redis]
    F -->|Return| G[User Info + Roles]
    
    B2[Keycloak] -->|Issue| B3[access_token]
    B3 -->|Exchange code| H[MinIO]
    H -->|Store in| I[MinIO Session]
    I -->|Validate| J[MinIO Backend]
```

---

## 🏗️ Kiến trúc SSO

```mermaid
graph TB
    subgraph "Frontend Network (10.10.1.0/24)"
        Nginx[Nginx Proxy<br/>10.10.1.10]
        Web[Web Server<br/>10.10.1.11]
        KC[Keycloak<br/>10.10.1.13]
    end
    
    subgraph "Backend Network (10.10.2.0/24)"
        MinIO[MinIO Console<br/>10.10.2.15]
    end
    
    User((👤 User)) -->|1. Login| Nginx
    Nginx -->|2. Auth| KC
    KC -->|3. Token| Nginx
    Nginx -->|4. Cookie| User
    
    User -->|5. Access /minio/| Nginx
    Nginx -->|6. Proxy| MinIO
    MinIO -->|7. SSO Redirect| KC
    KC -->|8. Auth Code| MinIO
    MinIO -->|9. Token Exchange| KC
    KC -->|10. Access Token| MinIO
    MinIO -->|11. Session| User
    
    style User fill:#e1f5ff
    style KC fill:#fff4e1
    style MinIO fill:#ffe1f5
```

---

## 📋 Cấu hình OIDC

### MinIO Environment Variables
```yaml
MINIO_IDENTITY_OPENID_CONFIG_URL: 
  "http://10.10.1.13:8080/auth/realms/realm_52300267/.well-known/openid-configuration"

MINIO_IDENTITY_OPENID_CLIENT_ID: "minio"

MINIO_IDENTITY_OPENID_CLIENT_SECRET: "<secret-from-keycloak>"

MINIO_IDENTITY_OPENID_SCOPES: "openid,profile,email"

MINIO_IDENTITY_OPENID_REDIRECT_URI: 
  "http://localhost:8088/minio/oauth_callback"

MINIO_IDENTITY_OPENID_CLAIM_NAME: "preferred_username"
```

### Keycloak Client Config
```json
{
  "clientId": "minio",
  "protocol": "openid-connect",
  "clientAuthenticatorType": "client-secret",
  "redirectUris": [
    "http://localhost:8088/minio/oauth_callback",
    "http://localhost:8088/minio/*"
  ],
  "webOrigins": ["http://localhost:8088"],
  "standardFlowEnabled": true,
  "directAccessGrantsEnabled": false
}
```

---

## 🔐 Security Features

### 1. Network Isolation
- MinIO nằm trong **backend-net** (internal)
- Chỉ Nginx có thể truy cập MinIO
- User không thể truy cập trực tiếp MinIO

### 2. Token Validation
- Keycloak validate token
- MinIO validate token với Keycloak
- Redis cache token cho Flask API

### 3. Session Management
- Keycloak session: 30 phút (configurable)
- MinIO session: theo token expiry
- Flask session: 15 phút (Redis TTL)

### 4. HTTPS Ready
- Nginx hỗ trợ SSL termination
- Keycloak hỗ trợ HTTPS
- MinIO hỗ trợ TLS

---

## 🎯 Benefits của SSO

✅ **Single Sign-On**: Đăng nhập 1 lần, dùng nhiều service  
✅ **Centralized Auth**: Quản lý user tập trung tại Keycloak  
✅ **Better UX**: Không cần nhập lại password  
✅ **Security**: Token-based, không lưu password  
✅ **Audit Trail**: Keycloak log tất cả login events  
✅ **Role-Based Access**: Keycloak roles → MinIO policies  

---

## 📊 Comparison: Trước vs Sau SSO

| Feature | Trước SSO | Sau SSO |
|---------|-----------|---------|
| **Login MinIO** | Username + Password riêng | Click "Login with SSO" |
| **User Management** | MinIO internal users | Keycloak centralized |
| **Password Reset** | MinIO admin phải reset | User tự reset qua Keycloak |
| **Multi-Factor Auth** | Không hỗ trợ | Keycloak MFA |
| **Session Timeout** | MinIO config | Keycloak config |
| **Audit Logs** | MinIO logs only | Keycloak + MinIO logs |

---

## 🧪 Testing Scenarios

### Scenario 1: Happy Path
1. ✅ User đăng nhập website
2. ✅ Truy cập MinIO Console
3. ✅ Click "Login with SSO"
4. ✅ Auto-redirect về MinIO Dashboard

### Scenario 2: No Website Login
1. ❌ User chưa đăng nhập website
2. ✅ Truy cập MinIO Console
3. ✅ Click "Login with SSO"
4. ✅ Redirect đến Keycloak login page
5. ✅ Nhập credentials
6. ✅ Redirect về MinIO Dashboard

### Scenario 3: Session Expired
1. ✅ User đã đăng nhập (session cũ)
2. ⏰ Session Keycloak hết hạn
3. ✅ Truy cập MinIO Console
4. ✅ Click "Login with SSO"
5. ✅ Keycloak yêu cầu đăng nhập lại
6. ✅ Redirect về MinIO Dashboard

### Scenario 4: Root User Login
1. ✅ Truy cập MinIO Console
2. ✅ Chọn "Login with credentials"
3. ✅ Nhập root username/password
4. ✅ Vào MinIO Dashboard với full admin rights

---

**Version**: 2.1  
**Last Updated**: April 15, 2026  
**Status**: ✅ Production Ready
