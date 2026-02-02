# flutter-project-2526

A comprehensive public speaking assessment tool built with Flutter, featuring audio recording analysis with confidence scoring.

## Quick Start

### Prerequisites
- Python 3.9+
- Flutter SDK
- Node.js (for web build)
- Supabase project configured

### Setup (One-time)

1. **Ensure Supabase is configured:**
   ```bash
   # Check that backend/.env has SUPABASE_URL and SUPABASE_KEY
   # These should be set from your Supabase project
   ```

2. **Create the recordings storage bucket** (if not already created):
   ```bash
   python backend/create_recordings_bucket.py
   ```

3. **Verify everything is working:**
   ```bash
   python backend/diagnose_recording.py
   ```

## Running the Application

### Terminal 1: Start Backend
```powershell
.\run_backend_8000.ps1
```

Wait for: `Application startup complete`

### Terminal 2: Start Web Frontend
```powershell
.\run_web_3000.ps1
```

Open: http://localhost:3000

## Features

- **Audio Recording**: Record speech samples directly from the browser
- **Real-time Analysis**: Acoustic analysis including pitch, jitter, shimmer
- **Confidence Scoring**: Get an overall speaking confidence score (0-100)
- **Playback**: Listen back to your recordings with "Listen to Your Voice" button
- **User Profiles**: Create and manage speaker profiles
- **Session History**: Track all analysis sessions with timestamps

## Creating Your First Recording

1. Open http://localhost:3000 in your browser
2. Go to **Practice** section
3. Click **Record** and speak for 10-60 seconds
4. Click **Stop** when done
5. Review the analysis metrics
6. Click **"Listen to Your Voice"** to hear your recording

## Troubleshooting

### Recording Playback Issues

If "Listen to Your Voice" shows an error:

```bash
# Run diagnostic
python backend/diagnose_recording.py
```

This will check:
- ✓ Backend is running
- ✓ Supabase is connected
- ✓ Storage bucket exists
- ✓ Recording file was uploaded

**Common issues:**
- **404 error**: Recording file doesn't exist → Create a NEW recording, file auto-uploads during analysis
- **Format error**: File uploaded but can't play → Backend logs will show the error
- **Connection refused**: Backend not running → Start with `.\run_backend_8000.ps1`

### Debug Endpoints

Test the backend manually:
```bash
# Backend health
curl http://localhost:8000/health

# Storage status
curl http://localhost:8000/debug/storage

# Check specific session
curl http://localhost:8000/debug/test-recording/{session-id}

# API docs
http://localhost:8000/docs
```

## Project Structure

```
├── backend/              # FastAPI server
│   ├── main.py          # API endpoints
│   ├── app/
│   │   ├── config.py    # Settings & .env loading
│   │   ├── database.py  # Supabase integration
│   │   └── analysis/    # Audio analysis pipeline
│   └── requirements.txt  # Python dependencies
│
├── lib/                  # Flutter app source
│   ├── main.dart        # App entry point
│   ├── features/        # Feature modules
│   │   ├── practice/    # Recording & playback
│   │   ├── analysis/    # Results display
│   │   ├── auth/        # Authentication
│   │   └── profile/     # User profiles
│   └── core/            # Shared services
│       └── services/
│           └── audio_service.dart  # Recording/playback logic
│
└── web/                  # Web assets
```

## Documentation

- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) - Setup verification guide
- [FIX_LISTEN_TO_YOUR_VOICE.md](FIX_LISTEN_TO_YOUR_VOICE.md) - Step-by-step fix guide
- [QUICK_DIAGNOSTIC_GUIDE.md](QUICK_DIAGNOSTIC_GUIDE.md) - Debug reference
- [DIAGNOSTIC_TOOLS_SUMMARY.md](DIAGNOSTIC_TOOLS_SUMMARY.md) - Implementation details
- [WEB_RECORDING_FEATURE.md](WEB_RECORDING_FEATURE.md) - Technical architecture