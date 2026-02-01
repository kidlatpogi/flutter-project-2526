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
} else {
    Write-Host "Activating virtual environment..."
    & ".\.venv\Scripts\Activate.ps1"
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

# Start the backend server
Set-Location backend
python main.py
