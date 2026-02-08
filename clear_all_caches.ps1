# ================================
# NUCLEAR CACHE CLEAR SCRIPT
# ================================
# Use this when code changes don't appear in browser
# This removes ALL caches and forces a complete rebuild

Set-Location -Path $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NUCLEAR CACHE CLEAR - FLUTTER WEB" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill all Chrome and Edge processes
Write-Host "[1/8] Killing all browser processes..." -ForegroundColor Yellow
Get-Process -Name chrome -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Step 2: Flutter clean
Write-Host "[2/8] Running flutter clean..." -ForegroundColor Yellow
flutter clean

# Step 3: Delete build directory
Write-Host "[3/8] Deleting build directory..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Path "build" -Recurse -Force
}

# Step 4: Delete .dart_tool
Write-Host "[4/8] Deleting .dart_tool directory..." -ForegroundColor Yellow
if (Test-Path ".dart_tool") {
    Remove-Item -Path ".dart_tool" -Recurse -Force
}

# Step 5: Clear Chrome caches
Write-Host "[5/8] Clearing Chrome cache..." -ForegroundColor Yellow
$chromeCachePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
)

foreach ($path in $chromeCachePaths) {
    if (Test-Path $path) {
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Step 6: Clear Edge caches
Write-Host "[6/8] Clearing Edge cache..." -ForegroundColor Yellow
$edgeCachePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
)

foreach ($path in $edgeCachePaths) {
    if (Test-Path $path) {
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Step 7: Get dependencies
Write-Host "[7/8] Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

# Step 8: Instructions
Write-Host "[8/8] Cache clear complete!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run one of these commands:" -ForegroundColor White
Write-Host ""
Write-Host "  For development (hot reload):" -ForegroundColor Yellow
Write-Host "  flutter run -d chrome --no-service-worker" -ForegroundColor Green
Write-Host ""
Write-Host "  For port 3000:" -ForegroundColor Yellow
Write-Host "  .\run_web_3000.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "  In Chrome DevTools:" -ForegroundColor Yellow
Write-Host "  1. Open DevTools (F12)" -ForegroundColor White
Write-Host "  2. Go to Application tab" -ForegroundColor White
Write-Host "  3. Click 'Clear storage'" -ForegroundColor White
Write-Host "  4. Check 'Unregister service workers'" -ForegroundColor White
Write-Host "  5. Click 'Clear site data'" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
