# Run this script to start the FastAPI backend server on port 8000
Set-Location -Path $PSScriptRoot

Write-Host "Starting FastAPI backend server on http://localhost:8000"
Write-Host ""

# Check if virtual environment exists
if (-not (Test-Path ".venv\Scripts\Activate.ps1")) {
    Write-Host "Virtual environment not found. Creating one..."
    python -m venv .venv
    & ".\.venv\Scripts\Activate.ps1"
    Write-Host "Installing dependencies..."
    pip install -r backend\requirements.txt
}

# Kill any existing processes on port 8000
$processes = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($processes) {
    Write-Host "Stopping existing processes on port 8000..."
    $processes | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
}

Write-Host "Starting server..."
Write-Host ""

# Start the backend server in a new window so it stays running
$uvicornPath = Join-Path $PSScriptRoot ".venv\Scripts\uvicorn.exe"
$backendPath = Join-Path $PSScriptRoot "backend"

Start-Process -FilePath $uvicornPath `
    -ArgumentList "main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info" `
    -WorkingDirectory $backendPath `
    -WindowStyle Normal

Write-Host "Backend server started in a new window."
Write-Host "API available at: http://localhost:8000"
Write-Host "API docs at: http://localhost:8000/docs"
Write-Host ""
Write-Host "To stop the server, close the backend window or run:"
Write-Host "  Stop-Process -Name uvicorn -Force"
