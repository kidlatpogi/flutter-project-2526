# Manual Setup: Create Supabase Storage Bucket

## The Problem

The `recordings` storage bucket doesn't exist in your Supabase project, so recordings can't be uploaded or retrieved.

## Solution: Create It Manually (2 Minutes)

### Step 1: Go to Supabase Dashboard

1. Open: https://app.supabase.com
2. Sign in
3. Select your project: **krbcgixttxxdofdmevyj**

### Step 2: Create Storage Bucket

1. Click **Storage** in the left sidebar
2. Click the blue **"Create bucket"** button
3. Fill in:
   - **Name**: `recordings` (exactly this)
   - Uncheck "Public bucket" (leave it private)
4. Click **Create bucket**

You should see "recordings" appear in your bucket list.

### Step 3: Set Up Permissions (Optional but Recommended)

Go to **SQL Editor** and run this:

```sql
-- Create policies for the recordings bucket
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

### Step 4: Restart Backend

```bash
# In your backend terminal
Ctrl+C

# Restart
python backend/main.py
```

### Step 5: Test It

1. Open the app: http://localhost:3000
2. Do a new practice recording
3. Complete the analysis
4. **Click "Listen to Your Voice"**
5. ✅ Audio should play!

---

## Verify It Works

Check the backend logs when you complete an analysis. You should see:
```
INFO: Uploading recording to storage: {user-id}/{session-id}.wav (size: XXXXX bytes)
INFO: Recording uploaded successfully: {user-id}/{session-id}.wav
```

---

## Troubleshooting

### Can't find the Create bucket button?
- Make sure you're in the Storage section (left sidebar → Storage)
- Look for a blue button or "+" icon

### Get an error when creating?
- The bucket name must be exactly: `recordings` (lowercase, no spaces)
- Try a different name if it still fails

### Still can't listen after setup?
1. Check bucket appears in Storage → Buckets list
2. Create a **new** recording (old ones won't have been uploaded)
3. Check backend logs for upload errors
4. Check browser console (F12) for network errors

---

## After Setup

Your system will work like this:

```
User Records → Backend Analyzes → Saves to Supabase Storage
                                         ↓
                            User clicks "Listen"
                                    ↓
                          Backend retrieves from Storage
                                    ↓
                           Web plays audio via URL
                                    ↓
                              ✅ User hears voice
```

That's it! Once the bucket exists, everything else happens automatically.
