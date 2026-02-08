# Run this from workspace root to start Flutter web on port 3000 using Microsoft Edge
Set-Location -Path $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter Web - Development Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting Flutter web app on http://localhost:3000" -ForegroundColor Green
Write-Host "Make sure your Google Cloud Console OAuth redirect URLs include:" -ForegroundColor Yellow
Write-Host "- http://localhost:3000" -ForegroundColor White
Write-Host "- http://localhost:3000/" -ForegroundColor White
Write-Host ""

# Kill any existing processes on port 3000
$processes = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if ($processes) {
    Write-Host "Stopping existing processes on port 3000..." -ForegroundColor Yellow
    $processes | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
}

# Kill existing browser instances to avoid cache issues
Write-Host "Closing existing Edge instances..." -ForegroundColor Yellow
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# Clean build artifacts to ensure fresh build
Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Flutter with cache-busting..." -ForegroundColor Green
Write-Host "Hot reload: Press 'r'" -ForegroundColor Yellow
Write-Host "Hot restart: Press 'R'" -ForegroundColor Yellow
Write-Host "Quit: Press 'q'" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run with cache-busting flags for development
flutter run -d edge `
    --web-port=3000 `
    --web-hostname=localhost `
    --web-renderer canvaskit `
    --dart-define=FLUTTER_WEB_USE_SKIA=true `
    --web-browser-flag="--disable-features=IsolateOrigins,site-per-process" `
    --web-browser-flag="--disable-web-security"
