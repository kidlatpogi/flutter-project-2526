# Fix: 500 Error on Recording Playback - Complete Solution

## What You're Seeing

```
❌ GET /sessions/{id}/recording → 500 Internal Server Error
❌ Failed to set source. Format error (Code: 4)
```

## The Root Cause

The `recordings` storage bucket doesn't exist in your Supabase project yet.

---

## ✅ Quick Fix (2 Minutes)

### 1. Create Storage Bucket Manually

Go to: **https://app.supabase.com**
1. Select project: **krbcgixttxxdofdmevyj**
2. Click **Storage** (left sidebar)
3. Click **Create bucket**
4. Name: `recordings` (exactly)
5. Uncheck "Public bucket"
6. Click **Create**

### 2. Restart Backend

```bash
# Terminal
Ctrl+C
python backend/main.py
```

### 3. Test It

- Do a new recording in the app
- Complete analysis
- Click "Listen to Your Voice"
- ✅ Audio should play!

---

## Why This Works

Once the bucket exists:

```
Recording Uploaded During Analysis
    ↓
Stored in: Supabase Storage / recordings / {user_id}/{session_id}.wav
    ↓
User clicks "Listen"
    ↓
Backend retrieves from Storage
    ↓
Streams as audio/wav to web player
    ↓
✅ Audio plays!
```

---

## Verify Setup

Check backend logs after completing an analysis. You should see:

```
INFO: Uploading recording to storage: {user_id}/{session_id}.wav (size: XXXXX bytes)
INFO: Recording uploaded successfully
```

If you see this, the upload worked! ✓

---

## Still Getting Error?

### Error: 404 "Recording not found"
- Bucket exists but file wasn't uploaded
- Solution: Check logs for upload errors, try new recording

### Error: 500 (Internal Server Error)
- Bucket doesn't exist or storage call failed
- Solution: Make sure bucket is created and visible in Storage tab

### Error: "Format error" in AudioPlayers
- The stored file is corrupted or not a valid WAV
- Solution: Create a new recording

---

## Complete Setup Guide

See: **`MANUAL_SETUP_STORAGE.md`** for detailed step-by-step instructions.

---

## Files Modified

- ✅ `backend/main.py` - Improved error handling and logging
- ✅ `MANUAL_SETUP_STORAGE.md` - Manual setup instructions
- ✅ Commit: `908a92c`

---

## Summary

```
┌─ Problem: 500 Error, No Recording
│
├─ Root Cause: recordings bucket missing
│
├─ Fix: Create bucket manually in Supabase
│
├─ Restart: Restart backend
│
└─ Test: New recording → Click "Listen" → ✅ Works!
```

**That's it!** The storage bucket is all you need. 🎉
