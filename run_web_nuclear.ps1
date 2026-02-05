# Flutter Web - NUCLEAR CACHE CLEAR

Write-Host "=== NUCLEAR CACHE CLEAR ===" -ForegroundColor Red
Write-Host ""

# Kill all Edge processes
Write-Host "[1/6] Killing Edge processes..." -ForegroundColor Yellow
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Flutter clean
Write-Host "[2/6] Flutter clean..." -ForegroundColor Yellow
flutter clean

# Delete build directory
Write-Host "[3/6] Deleting build directory..." -ForegroundColor Yellow
if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force }

# Clear Edge cache
Write-Host "[4/6] Clearing Edge cache..." -ForegroundColor Yellow
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\*" -Recurse -Force -ErrorAction SilentlyContinue

# Pub get
Write-Host "[5/6] Flutter pub get..." -ForegroundColor Yellow
flutter pub get

# Run
Write-Host "[6/6] Starting app in CHROME (better for dev)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Using Chrome instead of Edge for better cache control" -ForegroundColor Cyan
Write-Host "Press Ctrl+Shift+R to hard refresh if needed" -ForegroundColor Cyan
Write-Host ""
flutter run -d chrome --web-port=3000
