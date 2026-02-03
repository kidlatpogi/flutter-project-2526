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

⚠️ **Important**: Netlify doesn't have Flutter pre-installed. You must build locally and deploy the static files.

### Recommended: Build Locally + Drag & Drop

1. **Build Flutter Web**
```bash
flutter build web --release
```

2. **Deploy to Netlify**
   - Go to [netlify.com](https://netlify.com) and sign up
   - Click "Add new site" → "Deploy manually"
   - Drag the `build/web` folder to the upload area
   - Done! Your site is live

### Alternative: GitHub Actions + Netlify

If you want automatic deployments, use GitHub Actions to build and deploy:

1. **Create `.github/workflows/deploy.yml`**
```yaml
name: Deploy to Netlify

on:
  push:
    branches: [ main, 5.0.0 ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - run: flutter pub get
      - run: flutter build web --release
      
      - uses: netlify/actions/cli@master
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
        with:
          args: deploy --dir=build/web --prod
```

2. **Add secrets to GitHub**
   - Get Netlify auth token from netlify.com/user/applications
   - Get site ID from Netlify site settings
   - Add both as GitHub repository secrets

### Alternative: Firebase Hosting (Recommended for Flutter)

Firebase Hosting is better suited for Flutter web:

1. **Install Firebase CLI**
```bash
npm install -g firebase-tools
firebase login
```

2. **Initialize Firebase**
```bash
firebase init hosting
# Choose build/web as public directory
# Configure as single-page app: Yes
```

3. **Deploy**
```bash
flutter build web --release
firebase deploy --only hosting
```

### After Deployment
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
