# Environment Variables Setup Guide

## Railway Environment Variables

These are the variables you need to set in Railway for the backend to work.

### Supabase Configuration

You need 2 Supabase variables:

1. **SUPABASE_URL**
2. **SUPABASE_KEY**

#### How to Get These:

1. Go to [supabase.com](https://supabase.com) and log in to your project
2. Click "Settings" (bottom left)
3. Click "API" in the left menu
4. Copy these values:
   - **SUPABASE_URL** → Copy the "Project URL" (looks like `https://xxxxx.supabase.co`)
   - **SUPABASE_KEY** → Copy the "anon public" key (labeled `anon | public`)

### Setting Variables in Railway

1. Go to your Railway project dashboard
2. Click on your service (the one deploying)
3. Click "Variables" tab
4. Click "Add Variable"
5. Add these:

| Key | Value |
|-----|-------|
| `SUPABASE_URL` | `https://your-project.supabase.co` |
| `SUPABASE_KEY` | `eyJhbGciOiJIUzI1NiIs...` (the anon key) |

### Optional Variables

- **WHISPER_MODEL_SIZE**: Model size for Whisper (`tiny`, `base`, `small`, `medium`, `large`) - Default: `base`
- **MAX_AUDIO_DURATION_SECONDS**: Max audio length in seconds - Default: `600` (10 minutes)
- **ALLOWED_ORIGINS**: CORS allowed origins (comma-separated) - Example: `https://your-frontend.netlify.app,https://your-frontend.vercel.app`

### Example Complete Configuration

```
SUPABASE_URL=https://abcdefgh.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
WHISPER_MODEL_SIZE=base
MAX_AUDIO_DURATION_SECONDS=600
ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:3000
```

## Local Development (.env file)

For local testing, create a `.env` file in the `backend/` directory:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key-here
WHISPER_MODEL_SIZE=base
```

**Never commit .env to git** - it's in .gitignore already.

## Verify It Works

After setting variables in Railway:

1. Deploy again
2. Check the logs for startup messages
3. Should see: `[INFO] Uvicorn running on 0.0.0.0:8000`
4. If there's an error about missing variables, add them and redeploy

## Troubleshooting

**Error: "supabase_url not provided"**
- Make sure you added `SUPABASE_URL` variable to Railway

**Error: "supabase_key not provided"**
- Make sure you added `SUPABASE_KEY` variable to Railway

**Error: Connection refused**
- Check that the SUPABASE_URL is correct (no typos)
- Verify the SUPABASE_KEY is valid (anon public key, not secret key)

## Get Your Supabase Keys (Step-by-Step)

1. Open [supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project from the list
3. Go to **Settings** → **API** (left sidebar)
4. Look for these fields:
   - **Project URL** → This is your `SUPABASE_URL`
   - **anon | public** → This is your `SUPABASE_KEY` (NOT the secret key!)
5. Copy both values
6. Paste them into Railway variables
7. Redeploy

Done! Your backend will now connect to Supabase. 🎉
