#!/bin/sh
# Đọc Docker Secrets và export thành env vars cho Keycloak
# Keycloak 26+ không hỗ trợ _FILE variants natively

if [ -f /run/secrets/db_password ]; then
    export KC_DB_PASSWORD=$(cat /run/secrets/db_password)
fi

if [ -f /run/secrets/kc_admin_password ]; then
    export KEYCLOAK_ADMIN_PASSWORD=$(cat /run/secrets/kc_admin_password)
fi

# Chạy Keycloak với toàn bộ args được truyền vào
exec /opt/keycloak/bin/kc.sh "$@"
