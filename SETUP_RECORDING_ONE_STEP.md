# 🚀 One-Step Setup for Web Recording Playback

Your environment variables are already set! ✓

## Just One Command Away

Run this **one** command to set everything up:

```bash
python backend/setup_storage.py
```

That's it! This script will:
1. ✓ Verify your Supabase credentials
2. ✓ Create the `recordings` storage bucket
3. ✓ Set up access permissions
4. ✓ Verify everything works

## After Running setup_storage.py

1. **Restart the backend** (if it was running):
   ```bash
   Ctrl+C
   python backend/main.py
   ```

2. **Do a fresh practice recording** in the app:
   - Complete a session
   - Finish analysis

3. **Click "Listen to Your Voice"**
   - Audio should now play! ✅

## What If It Fails?

If `setup_storage.py` says it can't create the bucket, don't worry - just create it manually:

1. Go to: https://app.supabase.com
2. Select your project: **krbcgixttxxdofdmevyj**
3. Click **Storage** (left sidebar)
4. Click **Create bucket**
5. Name: `recordings`
6. Uncheck "Public bucket"
7. Click **Create**
8. Done! Restart backend and test.

## Troubleshooting

### ❌ "SUPABASE_KEY: NOT SET"
- Make sure `backend/.env` has the credentials
- Run: `python backend/setup_storage.py` again

### ❌ "Connection failed"
- Check your internet connection
- Verify credentials in `.env` are correct
- Check Supabase project status

### ❌ "Still can't listen to recordings"
- Verify bucket exists in Supabase Dashboard → Storage
- Create a **new** recording (old ones won't work)
- Check browser console for errors (F12)

---

**You've got this!** 🎉 Just run the setup script and you're done.
