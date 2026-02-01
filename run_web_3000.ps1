# Run this from workspace root to start Flutter web on port 3000 using Microsoft Edge
Set-Location -Path $PSScriptRoot

Write-Host "Starting Flutter web app on http://localhost:3000"
Write-Host "Make sure your Google Cloud Console OAuth redirect URLs include:"
Write-Host "- http://localhost:3000"
Write-Host "- http://localhost:3000/"
Write-Host ""

# Kill any existing processes on port 3000
$processes = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if ($processes) {
    Write-Host "Stopping existing processes on port 3000..."
    $processes | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
}

flutter run -d edge --web-port=3000 --web-hostname=localhost
