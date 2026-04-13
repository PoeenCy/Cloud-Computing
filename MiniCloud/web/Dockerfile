FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*
COPY html/ /usr/share/nginx/html/

# Script khởi động: inject INSTANCE_ID vào index.html trước khi nginx chạy
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
CMD ["/docker-entrypoint.sh"]
