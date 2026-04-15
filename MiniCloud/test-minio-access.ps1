# Script kiểm tra MinIO access

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  MinIO Access Test" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Container status
Write-Host "[TEST 1] Container status" -ForegroundColor Blue
$storage = docker ps --filter "name=minicloud-storage" --format "{{.Status}}"
$proxy = docker ps --filter "name=minicloud-proxy" --format "{{.Status}}"

if ($storage -match "Up") {
    Write-Host "  [OK] MinIO: $storage" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] MinIO không chạy" -ForegroundColor Red
    exit 1
}

if ($proxy -match "Up") {
    Write-Host "  [OK] Nginx: $proxy" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Nginx không chạy" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Network connectivity
Write-Host "[TEST 2] Network connectivity" -ForegroundColor Blue
$ping = docker exec minicloud-proxy ping -c 1 10.10.2.15 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Nginx có thể ping MinIO" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Nginx không thể ping MinIO" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: MinIO Console direct access
Write-Host "[TEST 3] MinIO Console direct access" -ForegroundColor Blue
$minio_test = docker exec minicloud-proxy wget -q -O- http://10.10.2.15:9001/ 2>&1
if ($minio_test -match "MinIO Console") {
    Write-Host "  [OK] MinIO Console đang chạy" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] MinIO Console không phản hồi" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 4: Nginx proxy to MinIO
Write-Host "[TEST 4] Nginx proxy to MinIO" -ForegroundColor Blue
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8088/minio/" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] HTTP 200 - MinIO accessible qua Nginx" -ForegroundColor Green
        
        # Check if response contains MinIO Console HTML
        if ($response.Content -match "MinIO Console") {
            Write-Host "  [OK] MinIO Console HTML loaded" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] Response không chứa MinIO Console HTML" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [WARNING] HTTP $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [ERROR] Không thể truy cập http://localhost:8088/minio/" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Check OIDC configuration
Write-Host "[TEST 5] OIDC configuration" -ForegroundColor Blue
$oidc_vars = docker exec minicloud-storage env 2>$null | Select-String "MINIO_IDENTITY_OPENID"
if ($oidc_vars) {
    Write-Host "  [OK] OIDC đã được cấu hình" -ForegroundColor Green
    $oidc_vars | ForEach-Object {
        $line = $_.ToString()
        if ($line -match "SECRET") {
            Write-Host "    MINIO_IDENTITY_OPENID_CLIENT_SECRET_FILE=***" -ForegroundColor Gray
        } else {
            Write-Host "    $line" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  [WARNING] OIDC chưa được cấu hình" -ForegroundColor Yellow
    Write-Host "  MinIO sẽ không có button 'Login with SSO'" -ForegroundColor Yellow
}
Write-Host ""

# Test 6: Check Nginx logs for errors
Write-Host "[TEST 6] Nginx logs (errors)" -ForegroundColor Blue
$nginx_errors = docker logs minicloud-proxy --tail 20 2>&1 | Select-String -Pattern "error.*minio"
if ($nginx_errors) {
    Write-Host "  [WARNING] Có lỗi trong Nginx logs:" -ForegroundColor Yellow
    $nginx_errors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
} else {
    Write-Host "  [OK] Không có lỗi liên quan đến MinIO" -ForegroundColor Green
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Kết luận" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Truy cập MinIO Console:" -ForegroundColor Yellow
Write-Host "  http://localhost:8088/minio/" -ForegroundColor White
Write-Host ""
Write-Host "Nếu vẫn không truy cập được:" -ForegroundColor Yellow
Write-Host "  1. Hard refresh browser: Ctrl + Shift + R" -ForegroundColor White
Write-Host "  2. Clear browser cache" -ForegroundColor White
Write-Host "  3. Thử Incognito mode" -ForegroundColor White
Write-Host "  4. Kiểm tra browser console (F12) xem có lỗi JS không" -ForegroundColor White
Write-Host ""
Write-Host "Nếu thấy 'Login with SSO' button:" -ForegroundColor Green
Write-Host "  [OK] Cấu hình thành công!" -ForegroundColor Green
Write-Host ""
