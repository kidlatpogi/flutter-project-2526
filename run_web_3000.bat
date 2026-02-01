@echo off
REM Run this from workspace root to start Flutter web on port 3000 using Microsoft Edge
cd /d "%~dp0"

echo Starting Flutter web app on http://localhost:3000
echo Make sure your Google Cloud Console OAuth redirect URLs include:
echo - http://localhost:3000
echo - http://localhost:3000/
echo.

REM Kill any existing processes on port 3000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3000') do (
    taskkill /f /pid %%a >nul 2>&1
)

flutter run -d edge --web-port=3000 --web-hostname=localhost
