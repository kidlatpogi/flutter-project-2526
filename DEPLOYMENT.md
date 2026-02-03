# Deployment Guide

## Backend Deployment (Railway)

### 1. Initial Setup
1. Push code to GitHub
2. Go to [railway.app](https://railway.app) and sign up
3. Click "New Project" → "Deploy from GitHub repo"
4. Select this repository

### 2. Configure Environment Variables
In Railway dashboard, add these variables:
```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_JWT_SECRET=your_supabase_jwt_secret
ALLOWED_ORIGINS=your_frontend_url
PORT=8000
```

### 3. Deploy
- Railway will automatically detect `nixpacks.toml` and deploy
- Wait for build to complete
- Copy the generated URL (e.g., `https://your-app.up.railway.app`)

### 4. Update Frontend
Update your Flutter app's API endpoint to use the Railway URL instead of `http://localhost:8000`

---

## Frontend Deployment (Netlify)

### 1. Build Flutter Web
```bash
flutter build web --release
```

### 2. Deploy to Netlify

**Option A: Drag & Drop**
1. Go to [netlify.com](https://netlify.com)
2. Drag the `build/web` folder to deploy

**Option B: CLI**
```bash
npm install -g netlify-cli
netlify login
netlify deploy --dir=build/web --prod
```

**Option C: GitHub Integration**
1. Connect your GitHub repo
2. Set build command: `flutter build web --release`
3. Set publish directory: `build/web`

### 3. Update Backend CORS
Update `ALLOWED_ORIGINS` in Railway to include your Netlify URL

---

## Alternative: Backend on Render

### 1. Create render.yaml
```yaml
services:
  - type: web
    name: bigkas-backend
    env: python
    buildCommand: cd backend && pip install -r requirements.txt
    startCommand: cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT
```

### 2. Deploy
1. Go to [render.com](https://render.com)
2. Connect GitHub repo
3. Render auto-detects Python and deploys

---

## Important Notes

- **FFmpeg**: Railway/Render should include it. If not, add to nixpacks.toml
- **Whisper Model**: First request will be slow (downloads model)
- **Free Tier Limits**: Railway gives $5/month free credit
- **CORS**: Always update ALLOWED_ORIGINS when changing domains
