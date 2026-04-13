# Keycloak upstream không ship microdnf; lấy curl + thư viện từ UBI 9 (cùng RHEL 9).
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest AS curl-src
RUN mkdir -p /export/lib64 \
    && cp -L /usr/bin/curl /export/curl \
    && ldd /usr/bin/curl | awk '/=>/ {print $3}' | grep -E '^/' | while read -r lib; do \
         case "$lib" in */libc.so.6|*/ld-linux*.so*) continue ;; esac; \
         base=$(basename "$lib"); cp -L "$lib" "/export/lib64/$base"; \
       done

FROM quay.io/keycloak/keycloak:latest
USER root
COPY --from=curl-src /export/curl /usr/bin/curl
COPY --from=curl-src /export/lib64/ /lib64/
COPY docker-entrypoint.sh /opt/keycloak/docker-entrypoint.sh
# Fix Windows CRLF line endings -> LF
RUN sed -i 's/\r//' /opt/keycloak/docker-entrypoint.sh \
    && chmod +x /opt/keycloak/docker-entrypoint.sh
USER keycloak
ENTRYPOINT ["/opt/keycloak/docker-entrypoint.sh"]
