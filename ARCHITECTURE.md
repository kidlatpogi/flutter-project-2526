# System Architecture & How It Works

## 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BIGKAS APP SYSTEM                            │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   USER'S COMPUTER    │
├──────────────────────┤
│                      │
│  ┌────────────────┐  │ Terminal 1 (PowerShell)
│  │  Backend:8000  │  │ .\run_backend_8000.ps1
│  │   FastAPI      │  │ 
│  │   Server       │  │
│  └────────┬────────┘  │
│           │           │
│           │ Python    │
│           │ Process   │
│  ┌────────▼────────┐  │ Terminal 2 (PowerShell)
│  │ Frontend:3000   │  │ .\run_web_3000.ps1
│  │   Flutter Web   │  │
│  │   (Chrome/Edge) │  │
│  └────────┬────────┘  │
│           │           │
│           │ HTTP/REST │
│           │ Requests  │
└───────────┼───────────┘
            │
            │ Internet
            │
            ▼
┌─────────────────────────┐
│    SUPABASE CLOUD       │
├─────────────────────────┤
│  ┌───────────────────┐  │
│  │ Auth Service      │  │ Manages user login
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ PostgreSQL DB     │  │ Stores:
│  │ • user_profiles   │  │   - Nicknames
│  │ • features        │  │   - Analysis results
│  │ • sessions        │  │   - User data
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ Storage Bucket    │  │ Stores audio files
│  └───────────────────┘  │
└─────────────────────────┘
```

---

## 🔄 Request Flow: Saving a Nickname

```
USER                    FRONTEND            BACKEND           SUPABASE
 │                        │                   │                  │
 ├─ Enters "John" ───────►│                   │                  │
 │                        │                   │                  │
 ├─ Clicks Save ─────────►│                   │                  │
 │                        │                   │                  │
 │                        ├─ GET /profile ───►│                  │
 │                        │                   ├─ Check JWT ───┐  │
 │                        │                   │                │  │
 │                        │                   │◄────── Valid ──┘  │
 │                        │                   │                  │
 │                        │◄─ 200 OK ────────┤                  │
 │                        │  {nickname:"John"}                  │
 │                        │                   │                  │
 │                        ├─ PUT /profile ───►│                  │
 │                        │ {nickname:"John"} │                  │
 │                        │                   ├─ Verify JWT ───┐ │
 │                        │                   │                 │ │
 │                        │                   │◄─── Valid ──────┘ │
 │                        │                   │                  │
 │                        │                   ├─ Update Profile ─┤
 │                        │                   │                  │
 │                        │                   │  UPDATE user_profiles
 │                        │                   │  SET nickname='John'
 │                        │                   │                  │
 │                        │                   │◄─ Success ──────┤
 │                        │                   │                  │
 │◄────── ✅ Success ────┤◄─ 200 OK ────────┤                  │
 │  Nickname saved!       │                   │                  │
 │                        │                   │                  │
```

---

## 🔌 Network Connections Required

```
┌─────────────────────────┐
│   LOCAL CONNECTIONS     │
├─────────────────────────┤
│                         │
│  Frontend ◄──────► Backend
│  :3000          :8000
│  (Chrome)       (Python FastAPI)
│
│  ✅ Must be on same machine or localhost
│  ✅ Both must be running simultaneously
│  ✅ Firewall must allow localhost traffic
│
└─────────────────────────┘

┌─────────────────────────────┐
│   CLOUD CONNECTIONS         │
├─────────────────────────────┤
│                             │
│  Backend ◄──────► Supabase
│  :8000    (HTTPS)
│           krbcgixttxxdofdmevyj.supabase.co
│
│  ✅ Requires internet connection
│  ✅ Uses Supabase credentials
│  ✅ Firewall must allow HTTPS
│
└─────────────────────────────┘
```

---

## 📋 Environment Setup

```
┌──────────────────────────────────────────┐
│         REQUIRED TO RUN                   │
├──────────────────────────────────────────┤
│                                          │
│  1. Python 3.8+ (for backend)           │
│     • FastAPI                           │
│     • Supabase SDK                      │
│     • Audio processing libraries        │
│                                          │
│  2. Flutter SDK (for frontend)          │
│     • Dart compiler                     │
│     • Flutter web support               │
│     • Chrome/Edge browser               │
│                                          │
│  3. Supabase Account (cloud database)   │
│     • PostgreSQL database               │
│     • Authentication system             │
│     • File storage                      │
│                                          │
│  4. Internet Connection                 │
│     • To reach Supabase in cloud       │
│     • To download dependencies          │
│                                          │
└──────────────────────────────────────────┘
```

---

## 🚀 Startup Sequence

### Step 1: Backend Server Starts
```
.\run_backend_8000.ps1
    ↓
Creates virtual environment
    ↓
Installs Python packages (first time only)
    ↓
Imports FastAPI modules
    ↓
Loads Whisper AI model
    ↓
Connects to Supabase
    ↓
Starts listening on port 8000
    ↓
Ready for requests from frontend
```

### Step 2: Frontend App Starts
```
.\run_web_3000.ps1
    ↓
Compiles Dart to JavaScript
    ↓
Starts Flutter development server on port 3000
    ↓
Opens browser to http://localhost:3000
    ↓
App initializes Supabase auth
    ↓
Shows splash screen → Login screen
    ↓
Ready for user interaction
```

### Step 3: User Saves Nickname
```
User enters nickname
    ↓
Frontend sends HTTP PUT request
    ↓
Backend receives request on port 8000
    ↓
Backend verifies JWT token from Supabase
    ↓
Backend updates Supabase database
    ↓
Backend sends response back to frontend
    ↓
Frontend shows success message
    ↓
Nickname is saved! ✅
```

---

## 🔐 Authentication Flow

```
┌─────────────────────────────────────────────────┐
│           HOW AUTHENTICATION WORKS              │
└─────────────────────────────────────────────────┘

1. USER REGISTERS/LOGINS
   ├─ Frontend shows login form
   ├─ User enters email + password
   ├─ Frontend sends to Supabase Auth
   └─ Supabase verifies and returns JWT token

2. FRONTEND STORES JWT TOKEN
   ├─ Token is saved in browser
   ├─ Token contains user ID ("sub")
   └─ Token expires after ~1 hour

3. WHEN MAKING REQUESTS
   ├─ Frontend includes token in header:
   │  Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
   ├─ Backend receives request
   ├─ Backend extracts user ID from token
   ├─ Backend uses user ID to access user's data
   └─ Backend sends response with user's data

4. IF TOKEN EXPIRES
   ├─ Backend returns 401 Unauthorized
   ├─ Frontend detects this
   ├─ Frontend redirects to login screen
   └─ User must login again to get new token
```

---

## 💾 Database Schema (Simplified)

```
Supabase PostgreSQL Database
├── auth.users (Supabase managed)
│   └── Handles user authentication
│
└── public schema
    ├── user_profiles
    │   ├── id (UUID, primary key)
    │   ├── nickname (varchar)
    │   ├── full_name (varchar)
    │   └── created_at (timestamp)
    │
    ├── features (analysis results)
    │   ├── session_id (UUID)
    │   ├── user_id (UUID, foreign key)
    │   ├── transcription (text)
    │   ├── confidence_score (float)
    │   └── ... (other metrics)
    │
    └── sessions (practice sessions)
        ├── id (UUID)
        ├── user_id (UUID, foreign key)
        ├── started_at (timestamp)
        └── ended_at (timestamp)
```

---

## 🐛 Error Detection & Recovery

```
┌─────────────────────────────────────────┐
│    ERROR HANDLING FLOW                   │
└─────────────────────────────────────────┘

Frontend tries to save nickname
    ↓
[Timeout or Connection Error]
    ├─ Backend not running → Connection Refused
    ├─ Port 8000 blocked → Connection Refused
    ├─ Server slow → Timeout after 30s
    ├─ Server error → HTTP 500
    └─ Auth expired → HTTP 401
    ↓
Frontend catches error and shows:
    ├─ If "Connection refused"
    │  → "Cannot connect to backend server. Make sure it is running on port 8000."
    ├─ If "Timeout"
    │  → "Connection timeout. Make sure the backend server is running."
    ├─ If "401 Unauthorized"
    │  → "Token expired. Please log in again."
    └─ Otherwise
        → Shows actual error from server
    ↓
User knows what to do ✅
```

---

## 📊 Performance Considerations

```
LOCAL vs CLOUD

LOCAL (Port 8000)
├─ Frontend → Backend: <10ms (same machine)
├─ Backend processing: 100-500ms
└─ Total response time: 100-510ms ✅ Fast

CLOUD (Supabase)
├─ Backend → Supabase: 50-200ms (internet)
├─ Supabase processing: 50-100ms
├─ Supabase → Backend: 50-200ms (internet)
└─ Total response time: 150-600ms ✅ Acceptable

USER EXPERIENCE
├─ Frontend waits 30 seconds max
├─ Show loading spinner during wait
├─ If timeout, show clear error
└─ User can retry
```

---

## 🎯 Troubleshooting Decision Tree

```
"Failed to save nickname"
    ├─ Backend not running?
    │  └─ Run: .\run_backend_8000.ps1
    │
    ├─ Backend crashed?
    │  └─ Check Terminal 1 for errors
    │
    ├─ Token expired?
    │  └─ Log out and log back in
    │
    ├─ Supabase down?
    │  └─ Check status.supabase.com
    │
    ├─ Firewall blocking port 8000?
    │  └─ Check Windows Defender Firewall
    │
    └─ Network issue?
        └─ Check internet connection
```

---

## 📝 Summary

The system has three main layers:

1. **Frontend** (Your browser)
   - Runs on http://localhost:3000
   - User interface
   - Makes HTTP requests

2. **Backend** (Python FastAPI)
   - Runs on http://localhost:8000
   - Processes requests
   - Talks to database

3. **Database** (Supabase in cloud)
   - Stores all data
   - Manages user authentication
   - Accessible via internet

**Key Point:** All three must be working for the app to function!

✅ This guide helps you understand how everything connects and what to do if something breaks.
