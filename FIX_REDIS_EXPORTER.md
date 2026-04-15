# Hướng dẫn sửa lỗi redis-exporter

## Vấn đề hiện tại
- File `docker-compose.yml` trên VM bị lỗi YAML syntax ở dòng 515
- Container `minicloud-redis-exporter` đang unhealthy vì healthcheck dùng `wget` nhưng container không có lệnh này

## Giải pháp: Copy lại file gốc từ Windows

### Bước 1: Thoát khỏi VM
```bash
exit
```

### Bước 2: Copy file docker-compose.yml từ Windows lên VM
Từ Command Prompt/PowerShell trên Windows:

```cmd
cd /d D:\Cloud-Computing\MiniCloud
gcloud compute scp docker-compose.yml minicloud-demo:~/MiniCloud/docker-compose.yml --zone=asia-southeast1-a
```

**Lưu ý**: File gốc đã có healthcheck đúng sử dụng shell TCP test thay vì wget

### Bước 3: SSH lại vào VM
```cmd
gcloud compute ssh minicloud-demo --zone=asia-southeast1-a
```

### Bước 4: Restart container redis-exporter
```bash
cd ~/MiniCloud
docker-compose up -d --force-recreate redis-exporter
```

### Bước 5: Kiểm tra trạng thái
```bash
docker-compose ps | grep redis
```

Kết quả mong đợi:
```
minicloud-redis                 Up (healthy)     6379/tcp
minicloud-redis-exporter        Up (healthy)     9121/tcp
```

### Bước 6: Kiểm tra healthcheck (sau 30 giây)
```bash
docker inspect minicloud-redis-exporter | grep -A 10 Healthcheck
```

Bạn sẽ thấy healthcheck đã đổi thành:
```json
"Test": [
    "CMD-SHELL",
    "timeout 5 sh -c 'echo > /dev/tcp/localhost/9121' || exit 1"
]
```

## Giải thích
- File gốc trên Windows đã có healthcheck đúng sử dụng shell TCP test
- Phương pháp này không cần `wget`, chỉ cần shell built-in `/dev/tcp`
- Sau khi copy và recreate, container sẽ healthy

## Nếu vẫn còn vấn đề
Nếu sau 1-2 phút container vẫn unhealthy, kiểm tra logs:
```bash
docker logs minicloud-redis-exporter
```

Hoặc xem chi tiết healthcheck:
```bash
docker inspect minicloud-redis-exporter --format='{{json .State.Health}}' | jq
```
