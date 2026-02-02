# How to Fix "Listen to Your Voice" Recording Playback Issues

## The Problem
You click "Listen to Your Voice" and get a 500 error or audio player error.

## The Solution (5 minutes)

### Step 1: Start the Backend

Open PowerShell and run:
```powershell
cd D:\Codes\Flutter\flutter_project2526
.\run_backend_8000.ps1
```

Wait for it to say "Application startup complete".

### Step 2: Run the Diagnostic Script

Open **another** PowerShell window and run:
```powershell
cd D:\Codes\Flutter\flutter_project2526
D:/Codes/Flutter/flutter_project2526/.venv/Scripts/python.exe backend/diagnose_recording.py
```

### Step 3: Follow the Prompts

The script will check:
- ✓ Backend is running
- ✓ Supabase is configured
- ✓ Storage bucket exists
- ✓ Your recording file exists

When prompted for a session ID, copy the ID from the error message and paste it.

### Step 4: Read the Results

The script will tell you exactly what's wrong:

**If all checks pass:**
- Refresh your browser
- Try clicking "Listen to Your Voice" again

**If "recordings" bucket is missing:**
- Go to https://app.supabase.com
- Click "Storage" → "Create new bucket"
- Name it: `recordings` (lowercase)
- Uncheck "Public bucket"
- Click Create

Then run the diagnostic again.

**If recording file is not found:**
- Create a NEW recording (old ones won't auto-upload)
- Complete the analysis
- Copy the new session ID
- Run the diagnostic script again

**If session is not found:**
- Make sure the session ID is correct (it's in the error)
- Make sure the analysis actually completed
- Check the backend terminal for errors

## If You Still Have Issues

1. **Check the backend terminal** - Look for error messages
2. **Check browser console** - Press F12, look at Network/Console tabs
3. **Create a new recording** - Sometimes the first one fails to upload
4. **Verify the bucket exists** - Go to https://app.supabase.com and check Storage

## Helpful Links

- Diagnostic script: `backend/diagnose_recording.py`
- Backend health check: http://localhost:8000/health
- Backend API docs: http://localhost:8000/docs
- Supabase console: https://app.supabase.com
- Detailed guide: [QUICK_DIAGNOSTIC_GUIDE.md](QUICK_DIAGNOSTIC_GUIDE.md)

## What's Happening Behind the Scenes

When you click "Listen to Your Voice":

1. **Web app** makes a request to: `http://localhost:8000/sessions/{id}/recording`
2. **Backend** tries to download the file from Supabase Storage
3. **Backend** sends the audio file to your browser
4. **AudioPlayers** plugin plays the audio

If any step fails, you get an error. The diagnostic script checks each step.

---

**Need the exact command to copy-paste?** Here it is:
```
D:/Codes/Flutter/flutter_project2526/.venv/Scripts/python.exe d:\Codes\Flutter\flutter_project2526\backend\diagnose_recording.py
```
