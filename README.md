# flutter-project-2526

# How to Run

1. 
cd D:\Codes\Flutter\flutter_project2526
.\run_backend_8000.ps1

2.
cd D:\Codes\Flutter\flutter_project2526
.\run_web_3000.ps1

# Troubleshooting Recording Playback

If "Listen to Your Voice" button shows error:

1. **Quick Diagnosis:**
   ```bash
   python backend/diagnose_recording.py
   ```
   This will tell you exactly what's wrong.

2. **Common Issues:**
   - Recordings bucket doesn't exist in Supabase → Create it manually
   - Recording wasn't uploaded → Create a new recording
   - Network/permission errors → Check backend logs

3. **Full Guide:**
   See: `MANUAL_SETUP_STORAGE.md` or `FIX_RECORDING_SIMPLE.md`