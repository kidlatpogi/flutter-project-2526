# Recording Playback Diagnostic Tools - Implementation Summary

## What Was Added

### 1. Enhanced Backend Debug Endpoints

#### `/debug/storage` (IMPROVED)
Shows available buckets and files in the recordings bucket.

**Response includes:**
- List of all buckets
- Whether 'recordings' bucket exists
- Number of files in bucket
- Timestamp

**Use case:** Verify bucket exists and see what recordings are stored

#### `/debug/test-recording/{session_id}` (NEW)
Detailed endpoint to test if a specific recording file exists and is accessible.

**Tests:**
1. Session exists in database
2. File path with user_id: `{user_id}/{session_id}.wav`
3. File path without user_id: `{session_id}.wav`
4. Lists all files in the recordings bucket

**Response includes:**
- Session found status
- User ID
- File access attempts with success/error for each path tried
- List of files in bucket
- Timestamp

**Use case:** Diagnose why a specific recording can't be played

### 2. Improved Diagnostic Script

**File:** `backend/diagnose_recording.py`

**Improvements:**
- Enhanced structured output with clear step markers [1/4], [2/4], etc.
- Uses the new `/debug/test-recording/{session_id}` endpoint
- Shows file access attempts in detail
- Lists files in bucket when they exist
- Clear action items for each failure mode
- Better error messages
- Exits on critical errors (missing config, bucket not exists)

**Features:**
1. Checks backend connectivity
2. Verifies Supabase configuration
3. Checks if recordings bucket exists
4. Tests specific session/recording
5. Shows diagnosis and next steps

**Output format:**
```
[1/4] Checking if backend is running...
   ✓ Backend is running
   ✓ Supabase connected: True

[2/4] Checking backend configuration...
   ✓ SUPABASE_URL: configured
   ✓ SUPABASE_KEY: configured

[3/4] Checking Supabase Storage...
   ✓ Available buckets: recordings, other
   ✓ 'recordings' bucket exists
   ℹ Files in bucket: 5

[4/4] Testing a specific recording...
   SESSION: 5a5f74b0-6254-450c-b353-4d8485973687
   ✓ Session found
   ℹ User ID: 123e4567-e89b-12d3-a456-426614174000
   
   FILE ACCESS ATTEMPTS:
   ✓ [1] 123e4567-e89b-12d3-a456-426614174000/5a5f74b0-6254-450c-b353-4d8485973687.wav - SUCCESS (45280 bytes)
```

### 3. Documentation Files

#### `QUICK_DIAGNOSTIC_GUIDE.md`
Quick reference for using diagnostic tools.
- When to use each endpoint
- What each response means
- Common issues and fixes
- Manual testing with cURL

#### `FIX_LISTEN_TO_YOUR_VOICE.md`
Step-by-step guide for fixing the issue.
- Start backend
- Run diagnostic
- Interpret results
- Create bucket if needed
- Re-record if needed

#### `README.md` (UPDATED)
Added quick troubleshooting section with diagnostic command.

## How It Works

### Diagnostic Flow

```
User gets error
    ↓
Run: python backend/diagnose_recording.py
    ↓
[1] Check backend running → GET /health
    ├─ Backend not running → STOP, start backend
    └─ Backend OK ↓
    
[2] Check Supabase config → GET /debug/info
    ├─ Config missing → STOP, check .env
    └─ Config OK ↓
    
[3] Check bucket exists → GET /debug/storage
    ├─ Bucket missing → STOP, create bucket manually
    └─ Bucket OK ↓
    
[4] Test recording file → GET /debug/test-recording/{id}
    ├─ Session not found → Check session ID
    ├─ File not found → Re-record, file will auto-upload
    └─ File found → Recording should play!
```

### Each Endpoint

**Health Check** (existing)
```
GET /health
→ Backend status, Supabase connected
```

**Config Check** (existing)
```
GET /debug/info
→ SUPABASE_URL configured?
→ SUPABASE_KEY configured?
→ Supabase connected?
```

**Storage Check** (improved)
```
GET /debug/storage
→ List all buckets
→ Is 'recordings' bucket in the list?
→ How many files in 'recordings'?
```

**Session Check** (existing)
```
GET /debug/session/{session_id}
→ Session exists in database?
→ What's the user_id?
→ Does recordings bucket exist?
→ Is file in bucket?
```

**Detailed Recording Test** (new)
```
GET /debug/test-recording/{session_id}
→ Session in database?
→ Try to download: {user_id}/{session_id}.wav
→ Try to download: {session_id}.wav
→ What files are actually in the bucket?
```

## Testing the Implementation

### Quick Test

1. Start backend:
```powershell
.\run_backend_8000.ps1
```

2. Check endpoints work:
```powershell
curl http://localhost:8000/health
curl http://localhost:8000/debug/info
curl http://localhost:8000/debug/storage
curl http://localhost:8000/debug/session/test-id
curl http://localhost:8000/debug/test-recording/test-id
```

3. Run diagnostic script:
```powershell
python backend/diagnose_recording.py
```

### Successful Outputs

When bucket exists and file is found:
```
[3/4] Checking Supabase Storage...
   ✓ 'recordings' bucket exists
   ℹ Files in bucket: 3

[4/4] Testing a specific recording...
   ✓ [1] 123.../session-id.wav - SUCCESS (45280 bytes)

DIAGNOSIS:
✓ SUCCESS: Recording file found!
```

When bucket is missing:
```
[3/4] Checking Supabase Storage...
   ✗ 'recordings' bucket NOT FOUND
   
   TO FIX:
   1. Go to https://app.supabase.com
   2. Click 'Storage' in the left sidebar
   3. Click 'Create new bucket'
   ...
```

When file is not uploaded:
```
[4/4] Testing a specific recording...
   ✗ [1] 123.../session-id.wav - FAILED (not found)

DIAGNOSIS:
✗ ERROR: Recording file NOT found in storage!

FIX: Try these steps:
  1. Create a NEW recording (old ones won't be auto-uploaded)
  2. Complete the analysis
  3. Run this script again with the new session ID
```

## Impact on User Experience

### Before
- User gets 500 error
- No idea what went wrong
- Has to guess:
  - Is backend running?
  - Is Supabase connected?
  - Is the bucket created?
  - Was the file uploaded?
  - Is there a permission issue?

### After
- User runs diagnostic script
- Script tells them exactly what's wrong
- Clear instructions for fixing each issue
- Can pinpoint the exact failure (bucket missing, file not uploaded, etc.)

## Files Modified

1. **backend/main.py**
   - Enhanced `/debug/storage` endpoint to list files
   - Added `/debug/test-recording/{session_id}` endpoint
   - Both endpoints provide detailed output for troubleshooting

2. **backend/diagnose_recording.py**
   - Rewritten to use new endpoints
   - Better structured output
   - Clear error messages and action items
   - Uses new `/debug/test-recording/{session_id}` for detailed testing

3. **README.md**
   - Added quick troubleshooting section
   - Links to diagnostic tools

4. **New files**
   - `QUICK_DIAGNOSTIC_GUIDE.md` - Reference for using debug endpoints
   - `FIX_LISTEN_TO_YOUR_VOICE.md` - Step-by-step fix guide

## Implementation Details

### Backend Error Handling

All debug endpoints include try/except blocks that:
1. Catch and log exceptions
2. Return structured error responses
3. Never crash the API

### Response Consistency

All responses include:
- `status` field (ok, error, connected, etc.)
- `timestamp` field (ISO format)
- Relevant data (buckets, files, sessions, etc.)
- `error` field if something failed

### Performance

- `/debug/storage` lists up to all files (minimal overhead)
- `/debug/test-recording/{id}` attempts 2 file downloads (acceptable for debug)
- Both endpoints are tagged as "Debug" so they're easy to identify

## Integration Points

### With Recording Upload

When a recording is uploaded during analysis:
```python
# backend/main.py - POST /analyze-audio
file_path = f"{user_id}/{session_id}.wav"
storage.from_("recordings").upload(file_path, file_data)
```

The diagnostic script will find it at exactly this path.

### With Audio Playback

When playing a recording:
```dart
// lib/features/practice/screens/analysis_result_screen.dart
String recordingUrl = 'http://localhost:8000/sessions/$sessionId/recording'
AudioPlayer().play(UrlSource(recordingUrl))
```

If this fails, the diagnostic tells you why.

## Future Enhancements

Possible improvements:
1. Add endpoint to create bucket automatically (if Supabase SDK allows)
2. Add endpoint to re-upload a recording
3. Add endpoint to verify WAV file integrity
4. Add endpoint to check RLS policies
5. Monitor upload/download success rates

## Usage Summary

For users:
```bash
# Run once to diagnose any recording issues
python backend/diagnose_recording.py
```

For developers:
```bash
# Test individual components
curl http://localhost:8000/debug/storage
curl http://localhost:8000/debug/test-recording/{session-id}
```
