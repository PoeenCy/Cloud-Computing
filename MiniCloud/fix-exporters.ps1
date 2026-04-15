# Script tự động sửa exporters

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Fix Exporters for Grafana Dashboards" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Fix 1: mysqld-exporter
Write-Host "[1/3] Fixing mysqld-exporter..." -ForegroundColor Blue
Write-Host "  Đang restart mysqld-exporter với config mới..." -ForegroundColor Yellow

# Backup docker-compose.yml
Copy-Item docker-compose.yml docker-compose.yml.backup -Force
Write-Host "  [OK] Backup: docker-compose.yml.backup" -ForegroundColor Green

# Restart mysqld-exporter
docker compose restart mysqld-exporter 2>&1 | Out-Null
Start-Sleep -Seconds 5

# Check logs
$logs = docker logs minicloud-mysqld-exporter --tail 5 2>&1 | Out-String
if ($logs -match "Error.*Access denied") {
    Write-Host "  [ERROR] mysqld-exporter vẫn lỗi!" -ForegroundColor Red
    Write-Host "  Vui lòng sửa thủ công theo hướng dẫn trong FIX_DASHBOARDS.md" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] mysqld-exporter đang chạy" -ForegroundColor Green
}
Write-Host ""

# Fix 2: Check Flask metrics
Write-Host "[2/3] Checking Flask metrics..." -ForegroundColor Blue
$flask_metrics = docker exec minicloud-monitoring wget -qO- "http://localhost:9090/prometheus/api/v1/query?query=flask_http_request_total" 2>&1 | ConvertFrom-Json
if ($flask_metrics.data.result.Count -gt 0) {
    Write-Host "  [OK] Flask metrics available ($($flask_metrics.data.result.Count) series)" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Flask metrics not found" -ForegroundColor Yellow
}
Write-Host ""

# Fix 3: Check if redis-exporter exists
Write-Host "[3/3] Checking redis-exporter..." -ForegroundColor Blue
$redis_exporter = docker ps --filter "name=redis-exporter" --format "{{.Names}}"
if ($redis_exporter) {
    Write-Host "  [OK] redis-exporter đang chạy" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] redis-exporter chưa được cài đặt" -ForegroundColor Yellow
    Write-Host "  Vui lòng thêm redis-exporter theo hướng dẫn trong FIX_DASHBOARDS.md" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Tóm tắt" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Kiểm tra Prometheus targets:" -ForegroundColor Yellow
Write-Host "  http://localhost:8088/prometheus/targets" -ForegroundColor White
Write-Host ""
Write-Host "Import Grafana dashboards:" -ForegroundColor Yellow
Write-Host "  - MySQL: ID 7362" -ForegroundColor White
Write-Host "  - Flask: ID 3662" -ForegroundColor White
Write-Host "  - Redis: ID 11835 (sau khi cài redis-exporter)" -ForegroundColor White
Write-Host ""
Write-Host "Xem hướng dẫn chi tiết: FIX_DASHBOARDS.md" -ForegroundColor Cyan
Write-Host ""
