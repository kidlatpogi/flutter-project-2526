# Bigkas - Public Speaking Assessment App

A Flutter web application with FastAPI backend for analyzing public speaking performance using AI.

## Quick Start

### First Time Setup

1. **Backend Setup**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Run the Application**
   - Backend: `.\run_backend_8000.ps1` (runs on http://localhost:8000)
   - Frontend: `.\run_web_3000.ps1` (runs on http://localhost:3000)

### Subsequent Runs

Simply run both scripts:
```bash
.\run_backend_8000.ps1
.\run_web_3000.ps1
```

## Tech Stack

- **Frontend**: Flutter Web
- **Backend**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth + Google Sign-In
- **Deployment**: Railway / Hugging Face Spaces