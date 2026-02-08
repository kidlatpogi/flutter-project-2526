# Quick Hot Reload - Chrome Development Mode
# Use this for fastest development with instant hot reload

Set-Location -Path $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QUICK DEV - Chrome Hot Reload" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kill existing Chrome instances
Write-Host "Closing Chrome..." -ForegroundColor Yellow
Get-Process -Name chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Starting Flutter in HOT RELOAD mode..." -ForegroundColor Green
Write-Host ""
Write-Host "TIP: Press 'r' for hot reload after saving changes" -ForegroundColor Yellow
Write-Host "TIP: Press 'R' for full hot restart" -ForegroundColor Yellow
Write-Host "TIP: Press 'q' to quit" -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run in debug mode for hot reload (no --release flag)
# This enables instant hot reload on Ctrl+S
flutter run -d chrome `
    --web-renderer html `
    --web-browser-flag="--disable-web-security" `
    --web-browser-flag="--user-data-dir=C:\temp\chrome_dev_profile"
