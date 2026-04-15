# Script restart MinIO với cấu hình OIDC mới

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  MinIO Restart Script - Apply OIDC Config" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Kiểm tra docker-compose.yml tồn tại
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "[ERROR] Không tìm thấy docker-compose.yml" -ForegroundColor Red
    Write-Host "Vui lòng chạy script trong thư mục MiniCloud" -ForegroundColor Yellow
    exit 1
}

# Kiểm tra secret file tồn tại
if (-not (Test-Path "secrets/minio_oidc_client_secret.txt")) {
    Write-Host "[ERROR] Không tìm thấy secrets/minio_oidc_client_secret.txt" -ForegroundColor Red
    Write-Host ""
    Write-Host "Vui lòng tạo file secret trước:" -ForegroundColor Yellow
    Write-Host "1. Lấy Client Secret từ Keycloak (Clients → minio → Credentials)" -ForegroundColor White
    Write-Host "2. Chạy lệnh:" -ForegroundColor White
    Write-Host '   "YOUR_CLIENT_SECRET" | Out-File -NoNewline -Encoding ASCII secrets/minio_oidc_client_secret.txt' -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Bước 1: Kiểm tra container hiện tại
Write-Host "[1/5] Kiểm tra MinIO container..." -ForegroundColor Blue
$container = docker ps --filter "name=minicloud-storage" --format "{{.Names}}"
if ($container) {
    Write-Host "  [OK] Container đang chạy: $container" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Container không chạy" -ForegroundColor Yellow
}
Write-Host ""

# Bước 2: Kiểm tra cấu hình OIDC hiện tại
Write-Host "[2/5] Kiểm tra cấu hình OIDC hiện tại..." -ForegroundColor Blue
$oidcVars = docker exec minicloud-storage env 2>$null | Select-String "MINIO_IDENTITY"
if ($oidcVars) {
    Write-Host "  [OK] OIDC đã được cấu hình:" -ForegroundColor Green
    $oidcVars | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  [WARNING] OIDC chưa được cấu hình" -ForegroundColor Yellow
    Write-Host "  Container đang chạy với cấu hình CŨ" -ForegroundColor Yellow
}
Write-Host ""

# Bước 3: Dừng container
Write-Host "[3/5] Dừng MinIO container..." -ForegroundColor Blue
docker compose stop storage 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Container đã dừng" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Không thể dừng container" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Bước 4: Xóa container cũ
Write-Host "[4/5] Xóa container cũ..." -ForegroundColor Blue
docker compose rm -f storage 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Container đã xóa" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Không thể xóa container" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Bước 5: Khởi động lại với cấu hình mới
Write-Host "[5/5] Khởi động MinIO với cấu hình mới..." -ForegroundColor Blue
docker compose up -d storage 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Container đã khởi động" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Không thể khởi động container" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Đợi container khởi động
Write-Host "Đợi MinIO khởi động (10 giây)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
Write-Host ""

# Kiểm tra kết quả
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Kiểm tra kết quả" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Kiểm tra container status
Write-Host "[CHECK 1] Container status:" -ForegroundColor Blue
$status = docker ps --filter "name=minicloud-storage" --format "{{.Status}}"
if ($status -match "Up") {
    Write-Host "  [OK] $status" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Container không chạy" -ForegroundColor Red
}
Write-Host ""

# Kiểm tra OIDC config
Write-Host "[CHECK 2] OIDC configuration:" -ForegroundColor Blue
$newOidcVars = docker exec minicloud-storage env 2>$null | Select-String "MINIO_IDENTITY"
if ($newOidcVars) {
    Write-Host "  [OK] OIDC đã được load:" -ForegroundColor Green
    $newOidcVars | ForEach-Object { 
        $line = $_.ToString()
        if ($line -match "CLIENT_SECRET") {
            Write-Host "    MINIO_IDENTITY_OPENID_CLIENT_SECRET=***" -ForegroundColor Gray
        } else {
            Write-Host "    $line" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  [ERROR] OIDC vẫn chưa được load" -ForegroundColor Red
    Write-Host "  Kiểm tra lại docker-compose.yml" -ForegroundColor Yellow
}
Write-Host ""

# Kiểm tra logs
Write-Host "[CHECK 3] MinIO logs (10 dòng cuối):" -ForegroundColor Blue
docker logs minicloud-storage --tail 10 2>&1 | ForEach-Object {
    if ($_ -match "OpenID") {
        Write-Host "  $_" -ForegroundColor Green
    } elseif ($_ -match "error|Error|ERROR") {
        Write-Host "  $_" -ForegroundColor Red
    } else {
        Write-Host "  $_" -ForegroundColor Gray
    }
}
Write-Host ""

# Kết luận
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Hoàn tất!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bước tiếp theo:" -ForegroundColor Yellow
Write-Host "1. Truy cập: http://localhost:8088/minio/" -ForegroundColor White
Write-Host "2. Kiểm tra có button 'Login with SSO' không" -ForegroundColor White
Write-Host "3. Nếu CHƯA có button:" -ForegroundColor White
Write-Host "   - Kiểm tra Client Secret trong docker-compose.yml" -ForegroundColor White
Write-Host "   - Chạy lại script này" -ForegroundColor White
Write-Host ""
Write-Host "Nếu CÓ button 'Login with SSO':" -ForegroundColor Green
Write-Host "  [OK] Cấu hình thành công! Click button để test" -ForegroundColor Green
Write-Host ""
