#!/bin/sh
# Inject INSTANCE_ID vào index.html (mặc định là 1 nếu không set)
INSTANCE_ID=${INSTANCE_ID:-1}

# Màu sắc badge theo instance
if [ "$INSTANCE_ID" = "1" ]; then
    BADGE_COLOR="#f97316"
    BADGE_SHADOW="rgba(249,115,22,0.4)"
    BADGE_EMOJI="🟠"
else
    BADGE_COLOR="#6366f1"
    BADGE_SHADOW="rgba(99,102,241,0.4)"
    BADGE_EMOJI="🟣"
fi

sed -i \
    -e "s|__INSTANCE_ID__|${INSTANCE_ID}|g" \
    -e "s|__BADGE_COLOR__|${BADGE_COLOR}|g" \
    -e "s|__BADGE_SHADOW__|${BADGE_SHADOW}|g" \
    -e "s|__BADGE_EMOJI__|${BADGE_EMOJI}|g" \
    /usr/share/nginx/html/index.html

exec nginx -g "daemon off;"
