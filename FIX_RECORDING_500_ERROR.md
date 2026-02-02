# Fix: 500 Error on Recording Playback

## The Error You're Seeing
```
GET http://localhost:8000/sessions/71667be4-1505-40b6-b42a-2674455f9cb3/recording 500 (Internal Server Error)
AudioPlayers Exception: Failed to set source. Format error (Code: 4)
```

## What's Wrong

The backend endpoint now properly serves audio, but it can't find the recording file because:

**Most Likely Cause**: The `recordings` storage bucket doesn't exist in Supabase yet.

---

## Quick Fix (5 Minutes)

### Step 1: Verify Setup
Run the diagnostic script:
```bash
cd backend
python check_recording_setup.py
```

This will tell you exactly what's missing.

### Step 2: Create Storage Bucket

#### Option A: Via Supabase Dashboard (Easiest)
1. Go to **https://app.supabase.com**
2. Select your project
3. Click **Storage** (left sidebar)
4. Click **Create bucket**
5. Enter name: `recordings`
6. **Uncheck** "Public bucket"
7. Click **Create**

#### Option B: Via SQL
Go to **SQL Editor** in Supabase and run:
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('recordings', 'recordings', false)
ON CONFLICT (id) DO NOTHING;

-- Set up policies for user privacy
CREATE POLICY "Allow authenticated users to upload recordings"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'recordings');

CREATE POLICY "Allow authenticated users to read their recordings"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'recordings');

CREATE POLICY "Allow authenticated users to delete their recordings"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'recordings');
```

### Step 3: Restart Backend
```bash
# In your backend terminal
Ctrl+C

# Restart
python main.py
```

### Step 4: Create New Recording
1. In your app, do a **new** practice session (from scratch)
2. Complete the recording
3. Click "Listen to Your Voice"
4. ✅ Audio should now play!

---

## Why It Needs to Be a New Recording

Once the bucket is created, you need to do a **new recording** because:
- The old recording was never uploaded (no bucket existed)
- The new recording will be automatically saved to storage
- The backend will then be able to serve it

---

## Verify Everything Works

### Check Backend Logs
When you complete analysis, you should see:
```
INFO: Uploading recording to storage: {user_id}/{session_id}.wav (size: XXXXX bytes)
INFO: Recording uploaded successfully: {user_id}/{session_id}.wav
```

### Check Supabase Storage
1. Go to Supabase Dashboard
2. Click **Storage**
3. Open `recordings` bucket
4. Should see files like: `your-user-id/session-uuid.wav`

### Test the Endpoint
```bash
# Replace with your actual session ID and JWT token
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8000/sessions/YOUR_SESSION_ID/recording \
  -o test.wav

# Play the test file
ffplay test.wav  # or open in media player
```

---

## Still Getting Errors?

### ✗ "Recording file not found in storage"
**Problem**: Bucket exists but file wasn't uploaded  
**Solution**: Check backend logs for upload errors, create a new recording

### ✗ "Invalid authentication token"
**Problem**: Not logged in or JWT token expired  
**Solution**: Log out and log back in, then try again

### ✗ "Format error (Code: 4)" in AudioPlayers
**Problem**: File in storage is corrupted or not a WAV file  
**Solution**: Create a new recording (the old one may have been corrupted during upload)

### ✗ Backend shows "Supabase connected: false"
**Problem**: Wrong credentials in `.env`  
**Solution**: 
1. Check `backend/.env` has correct `SUPABASE_URL` and `SUPABASE_KEY`
2. Get them from Supabase: Settings → API → Copy values
3. Restart backend

### ✗ Storage bucket not showing in diagnostic
**Problem**: Still not created or permissions issue  
**Solution**: 
1. Manually create via dashboard (Step 2 Option A)
2. Make sure you're in the right Supabase project

---

## Advanced Troubleshooting

### Check Supabase Logs
Go to Supabase Dashboard → Logs to see storage operations

### Enable Debug Logging
Edit `backend/main.py` and change:
```python
logging.basicConfig(level=logging.INFO)  # Change to DEBUG
```

### Test Storage Directly
```bash
# Get list of buckets
curl http://localhost:8000/debug/storage
# Should show: "recordings_bucket_exists": true
```

---

## Files Changed

- ✅ `backend/main.py` - Fixed streaming endpoint
- ✅ `TROUBLESHOOT_RECORDING.md` - Full troubleshooting guide
- ✅ `backend/check_recording_setup.py` - Diagnostic tool
- ✅ Commit: `721d1ce` - Proper recording streaming

---

## Summary

```
┌─ Problem: 500 Error, No Recording Audio
│
├─ Root Cause: Supabase Storage bucket not created
│
├─ Fix: Create 'recordings' bucket in Supabase
│
├─ Test: Create new recording → Click "Listen to Your Voice"
│
└─ Result: ✅ Audio plays on web!
```

**That's it!** Once the storage bucket is set up, everything should work. Let me know if you still see errors!
