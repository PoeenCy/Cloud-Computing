FROM ubuntu/bind9:latest

# Yêu cầu User root để cài đặt gói mạng
USER root

# Cài đặt dnsutils để có lệnh 'dig' và 'host' phục vụ Deep Healthcheck
RUN apt-get update && apt-get install -y dnsutils && rm -rf /var/lib/apt/lists/*

# Trả lại quyền (nếu cần, entrypoint của ubuntu/bind9 tự xử lý việc drop privileges)
