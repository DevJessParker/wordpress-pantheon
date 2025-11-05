# Recovery script for Lando startup issues
Write-Host "Starting recovery process..." -ForegroundColor Cyan

# Step 1: Stop everything
Write-Host "`n[1/5] Stopping all Lando services..." -ForegroundColor Yellow
lando poweroff 2>&1 | Out-Null
Start-Sleep -Seconds 3

# Step 2: Destroy the corrupted project
Write-Host "[2/5] Destroying corrupted project..." -ForegroundColor Yellow
lando destroy -y 2>&1 | Out-Null
Start-Sleep -Seconds 2

# Step 3: Clean up vendor directory
Write-Host "[3/5] Cleaning up vendor directory..." -ForegroundColor Yellow
if (Test-Path "vendor") {
    Remove-Item -Recurse -Force vendor -ErrorAction SilentlyContinue
    Write-Host "    Vendor directory removed" -ForegroundColor Green
}

# Step 4: Clean up wordpress directory if partially installed
Write-Host "[4/5] Cleaning up WordPress directory..." -ForegroundColor Yellow
if (Test-Path "wordpress") {
    Remove-Item -Recurse -Force wordpress -ErrorAction SilentlyContinue
    Write-Host "    WordPress directory removed" -ForegroundColor Green
}

# Step 5: Update Lando (recommended)
Write-Host "`n[5/5] Checking Lando version..." -ForegroundColor Yellow
$landoVersion = & lando version 2>&1
Write-Host "    Current version: $landoVersion" -ForegroundColor Cyan

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Recovery complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Update Lando to stable version:" -ForegroundColor White
Write-Host "   Visit: https://github.com/lando/lando/releases/latest" -ForegroundColor Gray
Write-Host "   Download: lando-x64-stable.exe" -ForegroundColor Gray
Write-Host "   Run installer (will upgrade beta to stable)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. After updating Lando, run:" -ForegroundColor White
Write-Host "   .\quickstart.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "OR to continue with current beta version:" -ForegroundColor White
Write-Host "   .\quickstart.ps1" -ForegroundColor Gray
Write-Host "   (May encounter same Docker image issue)" -ForegroundColor Red
