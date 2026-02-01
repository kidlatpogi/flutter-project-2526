# Setup Instructions

## Prerequisites
- Flutter SDK
- Python 3.8+
- Node.js (for development tools)

## Quick Start

### 1. Start the Backend Server

Open PowerShell in the project root and run:

```powershell
.\run_backend_8000.ps1
```

This will:
- Create a Python virtual environment if it doesn't exist
- Install dependencies from `backend/requirements.txt`
- Start the FastAPI backend server on `http://localhost:8000`

**Backend Server Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

### 2. Start the Flutter Web App (in a new PowerShell window)

```powershell
.\run_web_3000.ps1
```

This will:
- Start the Flutter web development server on `http://localhost:3000`
- Open Microsoft Edge automatically

**Expected Output:**
```
Launching lib\main.dart on Edge in debug mode...
Flutter run key commands.
r Hot reload.
R Hot restart.
d Detach (terminate "flutter run" but leave application running).
q Quit (terminate the application on the device).
```

## Troubleshooting

### "Failed to save nickname. Please Try again"

This error occurs when the Flutter app cannot connect to the backend. Make sure:

1. **Backend is running** - Check that the backend server is running on port 8000
   ```
   Check: http://localhost:8000/health
   ```

2. **Port 8000 is available** - If you get "Address already in use", run:
   ```powershell
   # Kill processes on port 8000
   Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | 
     ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
   ```

3. **Backend configuration** - Verify `.env` in the backend folder has:
   ```
   SUPABASE_URL=https://krbcgixttxxdofdmevyj.supabase.co
   SUPABASE_KEY=sb_secret_iOEuMim2Y0z3niKqOZx9Kg_I7MpsSPO
   WHISPER_MODEL_SIZE=base
   ```

4. **Check backend logs** - Look for errors in the backend server console

### Other Issues

- **"Connection timeout"** - Backend is not responding. Check if server process is running.
- **"Unauthorized: Token may have expired"** - Log out and log back in to refresh the token.
- **Database errors** - Verify Supabase credentials and database schema are set up correctly.

## Architecture

```
┌─────────────────────────┐
│  Flutter Web (port 3000)│
└────────────┬────────────┘
             │
             │ HTTP Requests
             ▼
┌─────────────────────────────────┐
│  FastAPI Backend (port 8000)    │
├──────────────────────────────────┤
│ - Profile Management             │
│ - Audio Analysis                 │
│ - Speech Recognition             │
└────────────┬──────────────────────┘
             │
             │ Supabase SDK
             ▼
┌─────────────────────────────────┐
│  Supabase (PostgreSQL + Auth)   │
├──────────────────────────────────┤
│ - User Profiles                  │
│ - Analysis Results               │
│ - Authentication                 │
└─────────────────────────────────┘
```

## Development Workflow

1. Backend changes: Just edit files, the server auto-reloads with `reload=True`
2. Frontend changes: Use `r` (hot reload) or `R` (hot restart) in the Flutter terminal
3. Database changes: Run SQL in Supabase console

## Backend Environment Variables

Create `backend/.env`:
```env
# Supabase Configuration (REQUIRED)
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key

# Whisper Model Size (tiny, base, small, medium, large)
# Default: base
WHISPER_MODEL_SIZE=base

# Audio Processing
MAX_AUDIO_DURATION_SECONDS=600
```

## Useful Commands

### Check if services are running
```powershell
# Check backend on port 8000
Test-NetConnection localhost -Port 8000

# Check Flutter on port 3000
Test-NetConnection localhost -Port 3000
```

### Kill services on specific ports
```powershell
# Kill on port 8000
Get-NetTCPConnection -LocalPort 8000 | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }

# Kill on port 3000
Get-NetTCPConnection -LocalPort 3000 | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

### View backend logs
The backend logs appear in the terminal window running the server. Look for:
- `INFO: Profile update response status: 200` - Successful save
- `ERROR: Failed to update profile` - Error details

### Hot reload Flutter
While the Flutter server is running:
- Press `r` to hot reload (fast, preserves state)
- Press `R` to hot restart (slower, resets state)
- Press `q` to quit
