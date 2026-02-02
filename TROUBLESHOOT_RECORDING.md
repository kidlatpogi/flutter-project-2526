# Web Recording Playback - Troubleshooting

## Error: 500 Internal Server Error on GET /sessions/{id}/recording

### Problem
The backend endpoint returns 500 when trying to fetch recordings, and the frontend shows:
```
AudioPlayers Exception: Failed to set source. Format error (Code: 4)
```

### Root Causes

1. **Supabase Storage Bucket Not Created**
   - The `recordings` bucket doesn't exist
   - Upload fails silently, so the endpoint can't find the file

2. **Storage Permissions Not Configured**
   - RLS policies not set up
   - Service role key doesn't have access

3. **Incorrect Supabase Credentials**
   - `SUPABASE_URL` or `SUPABASE_KEY` not set in `.env`
   - Backend can't connect to storage

### Solution: Verify and Setup Storage

#### Step 1: Check Supabase Connection
```bash
# Call the debug endpoint
curl http://localhost:8000/debug/storage
```

Expected response:
```json
{
  "status": "connected",
  "buckets": ["recordings"],
  "recordings_bucket_exist": true,
  "timestamp": "2026-02-02T..."
}
```

#### Step 2: Create Storage Bucket

Go to **Supabase Dashboard** → **Storage**

Option A (Via Dashboard UI):
1. Click "Create bucket"
2. Name: `recordings`
3. Uncheck "Public bucket" 
4. Click Create

Option B (Via SQL):
```sql
-- Run in Supabase SQL Editor
INSERT INTO storage.buckets (id, name, public)
VALUES ('recordings', 'recordings', false)
ON CONFLICT (id) DO NOTHING;
```

#### Step 3: Set Up RLS Policies

Run in **Supabase SQL Editor**:
```sql
-- Allow authenticated users to upload recordings
CREATE POLICY "Allow authenticated users to upload recordings"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'recordings');

-- Allow authenticated users to read their recordings  
CREATE POLICY "Allow authenticated users to read their recordings"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'recordings');

-- Allow authenticated users to delete their recordings
CREATE POLICY "Allow authenticated users to delete their recordings"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'recordings');
```

#### Step 4: Verify Environment Variables

Check `backend/.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key
```

**How to get these:**
1. Go to Supabase Dashboard
2. Settings → API
3. Copy `Project URL` → `SUPABASE_URL`
4. Copy `service_role` secret → `SUPABASE_KEY`

#### Step 5: Restart Backend
```bash
# Kill the running backend
Ctrl+C

# Restart
python backend/main.py
```

### Testing the Fix

#### 1. Verify Storage is Ready
```bash
curl http://localhost:8000/debug/storage
# Should show recordings_bucket_exists: true
```

#### 2. Create a New Recording
1. Open web app: `http://localhost:3000`
2. Complete a practice session
3. Finish recording → Analysis
4. Check backend logs:
   ```
   INFO: Uploading recording to storage: {user_id}/{session_id}.wav
   INFO: Recording uploaded successfully
   ```

#### 3. Listen to Recording
- Click "Listen to Your Voice" button
- Audio should play
- Check browser console for errors

### If Still Getting Errors

#### Check Backend Logs
Look for these messages:
- `Uploading recording to storage` - Recording is being saved
- `Recording uploaded successfully` - Upload worked
- `Failed to retrieve recording from storage` - Storage fetch failed

#### Common Issues

**Error: "Recording file not found in storage"**
- Storage bucket was created AFTER analysis
- Solution: Do another analysis after bucket is created

**Error: "Invalid authentication token"**
- User not authenticated
- Solution: Make sure you're logged in when requesting

**Error: "You do not have access to this recording"**
- Logged in as different user
- Solution: Use same account that created the recording

**Error: "Format error (Code: 4)" in AudioPlayers**
- File in storage is not a valid WAV file
- Solution: Re-do the recording (corrupted upload)

### Fallback: Serve from Memory

If you want to test without Supabase Storage, modify the endpoint to serve from a temporary location:

```python
@app.get("/sessions/{session_id}/recording")
async def get_session_recording(session_id: str):
    # TODO: Implement fallback for testing
    # Return a sample WAV file for testing purposes
    pass
```

### Manual Testing

#### Using cURL
```bash
# Get a recording (replace with real session ID)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8000/sessions/71667be4-1505-40b6-b42a-2674455f9cb3/recording \
  > test_recording.wav

# Play it
ffplay test_recording.wav
```

#### Using Frontend
1. Complete analysis
2. Open browser DevTools (F12)
3. Go to Network tab
4. Click "Listen to Your Voice"
5. Check if request succeeds
6. Look at response headers (should be audio/wav)

### Quick Checklist

- [ ] Storage bucket `recordings` created in Supabase
- [ ] RLS policies configured for storage
- [ ] `SUPABASE_URL` set in `.env`
- [ ] `SUPABASE_KEY` set in `.env`
- [ ] Backend restarted after `.env` changes
- [ ] `/debug/storage` endpoint returns `recordings_bucket_exists: true`
- [ ] New recording was created AFTER bucket setup
- [ ] User is authenticated with JWT token
- [ ] Audio file is valid WAV format

### Getting Help

Check these logs:
```bash
# Backend logs (terminal where python main.py is running)
# Look for errors with "storage" or "upload"

# Browser console (F12 → Console)
# Look for CORS errors or failed network requests
```
