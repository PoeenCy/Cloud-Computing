#!/usr/bin/env pwsh
# Script rebuild và push tất cả images lên DockerHub
# Usage: .\push-to-dockerhub.ps1

$DOCKERHUB_USER = "poeency"
$REPO = "$DOCKERHUB_USER/cloud-computing"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Push MiniCloud Images to DockerHub" -ForegroundColor Cyan
Write-Host "  Repo: $REPO" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Kiểm tra đã login chưa
$loginCheck = docker info 2>&1 | Select-String "Username"
if (-not $loginCheck) {
    Write-Host "[!] Chưa login DockerHub. Đang login..." -ForegroundColor Yellow
    docker login -u $DOCKERHUB_USER
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Login thất bại!" -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Đã login DockerHub" -ForegroundColor Green
Write-Host ""

# Danh sách images cần build và push
$services = @(
    @{ Name = "app";  Context = "./app";   Tag = "app-latest"  },
    @{ Name = "web";  Context = "./web";   Tag = "web-latest"  },
    @{ Name = "auth"; Context = "./auth";  Tag = "auth-latest" },
    @{ Name = "dns";  Context = "./bind9"; Tag = "dns-latest"  }
)

$failed = @()

foreach ($svc in $services) {
    $fullTag = "${REPO}:$($svc.Tag)"
    Write-Host "--------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[BUILD] $($svc.Name) → $fullTag" -ForegroundColor Blue

    # Build
    docker build -t $fullTag $svc.Context
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build $($svc.Name) thất bại!" -ForegroundColor Red
        $failed += $svc.Name
        continue
    }
    Write-Host "[OK] Build $($svc.Name) thành công" -ForegroundColor Green

    # Push
    Write-Host "[PUSH] Đang push $fullTag..." -ForegroundColor Blue
    docker push $fullTag
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Push $($svc.Name) thất bại!" -ForegroundColor Red
        $failed += $svc.Name
        continue
    }
    Write-Host "[OK] Push $($svc.Name) thành công" -ForegroundColor Green
    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Kết quả" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($failed.Count -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] Tất cả images đã được push thành công!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Images trên DockerHub:" -ForegroundColor Yellow
    foreach ($svc in $services) {
        Write-Host "  docker pull ${REPO}:$($svc.Tag)" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "[FAILED] Các images sau bị lỗi: $($failed -join ', ')" -ForegroundColor Red
    Write-Host "Hãy kiểm tra lại và chạy lại script" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "DockerHub: https://hub.docker.com/r/$REPO/tags" -ForegroundColor Cyan
