#!/bin/sh
# Chỉ truyền INSTANCE_ID vào container, JS sẽ đọc qua meta tag
INSTANCE_ID=${INSTANCE_ID:-1}

# Inject meta tag vào <head> — an toàn với UTF-8, không dùng sed trên toàn file
sed -i "s|</head>|<meta name=\"instance-id\" content=\"${INSTANCE_ID}\">\n</head>|" \
    /usr/share/nginx/html/index.html

exec nginx -g "daemon off;"
