# Quick Diagnostic Guide: Recording Playback Issues

If "Listen to Your Voice" button shows an error, use this guide to fix it.

## Quick Diagnosis (2 minutes)

### 1. Start the backend
```bash
.\run_backend_8000.ps1
```

### 2. Run the diagnostic script
```bash
cd d:\Codes\Flutter\flutter_project2526
D:/Codes/Flutter/flutter_project2526/.venv/Scripts/python.exe backend/diagnose_recording.py
```

### 3. When prompted, enter the session ID
The session ID is shown in the error message when you try to play a recording.

## What the Diagnostic Script Will Tell You

### ✓ All 4 checks pass
**Everything is working!** The recording should play. If it still doesn't:
1. Refresh the browser
2. Check browser console (F12) for errors
3. Try creating a NEW recording

### ✗ "recordings" bucket NOT FOUND
The storage bucket wasn't created.

**Fix:**
1. Go to https://app.supabase.com
2. Click "Storage" in left sidebar
3. Click "Create new bucket"
4. Enter name exactly: `recordings` (lowercase)
5. Leave "Public bucket" **unchecked**
6. Click "Create bucket"

### ✗ Recording file NOT found in storage
The analysis completed but the file wasn't uploaded.

**Fix:**
1. Create a NEW recording
2. Complete the analysis
3. Check the backend terminal for upload errors
4. Run the diagnostic script again with the new session ID

### ✗ Session not found
The session ID doesn't exist in the database.

**Fix:**
1. Make sure you copied the session ID correctly
2. Make sure the analysis actually completed
3. Check backend logs

## Backend Debug Endpoints

These endpoints are useful if you want to test manually:

### Health Check
```
GET http://localhost:8000/health
```
Returns: Backend status, Supabase connection, model status

### Configuration Check
```
GET http://localhost:8000/debug/info
```
Returns: Whether .env is configured

### Storage Status
```
GET http://localhost:8000/debug/storage
```
Returns: Available buckets, whether "recordings" exists, files in bucket

### Session Details
```
GET http://localhost:8000/debug/session/{session_id}
```
Returns: Session found, user ID, bucket status

### Recording File Test
```
GET http://localhost:8000/debug/test-recording/{session_id}
```
Returns: Detailed file access attempts with error messages

## Manual Testing with cURL

Test the recording endpoint directly:
```bash
curl -v http://localhost:8000/sessions/{session_id}/recording -o test.wav
```

If this downloads a valid WAV file, the issue is likely with:
- Browser/app audio player configuration
- CORS headers
- Content-Type header

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| 500 error on `/sessions/{id}/recording` | Bucket doesn't exist | Create "recordings" bucket |
| 404 error | Recording file not found | Create new recording, file will auto-upload |
| 0 bytes downloaded | File exists but is empty | Re-analyze (recording wasn't saved properly) |
| "Format error (Code: 4)" in AudioPlayers | URL returns non-audio data | Check network response in F12 |
| Session not found | Wrong session ID | Copy exact ID from error message |

## Need More Help?

See the detailed guides:
- [WEB_RECORDING_FEATURE.md](WEB_RECORDING_FEATURE.md) - Technical details
- [TROUBLESHOOT_RECORDING.md](TROUBLESHOOT_RECORDING.md) - Detailed troubleshooting
- [MANUAL_SETUP_STORAGE.md](MANUAL_SETUP_STORAGE.md) - Manual bucket creation

## Backend Logs

Check the backend terminal for detailed error messages:

```
INFO: Analyzing audio...
INFO: Saving recording to storage
INFO: Uploading recording to Supabase Storage
INFO: Recording uploaded successfully
```

If you see errors here, that's the issue.

## Testing the Full Flow

1. **Record audio** - Click microphone icon
2. **Complete analysis** - See metrics displayed
3. **Click "Listen to Your Voice"** - Recording should play
4. **Check browser console** (F12) - Look for network errors

## Quick URLs

- Supabase console: https://app.supabase.com
- Backend health: http://localhost:8000/health
- Swagger docs: http://localhost:8000/docs
