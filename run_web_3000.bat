@echo off
REM Run this from workspace root to start Flutter web on port 3000 using Microsoft Edge
cd /d "%~dp0"
flutter run -d edge --web-port=3000 --web-hostname=localhost
