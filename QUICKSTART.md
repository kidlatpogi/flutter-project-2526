# Quick Start Guide

## 🚀 Get Running in 2 Steps

### Step 1: Start Backend Server
Open **PowerShell** and run:
```powershell
cd D:\Codes\Flutter\flutter_project2526
.\run_backend_8000.ps1
```

**Expected output:**
```
Starting FastAPI backend server on http://localhost:8000
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

✅ Leave this window open!

---

### Step 2: Start Flutter Frontend
Open a **NEW PowerShell window** and run:
```powershell
cd D:\Codes\Flutter\flutter_project2526
.\run_web_3000.ps1
```

**Expected output:**
```
Starting Flutter web app on http://localhost:3000
Flutter run key commands.
r Hot reload.
R Hot restart.
d Detach.
q Quit.
```

✅ Your browser will open to http://localhost:3000

---

## 📱 The App is Now Ready!

- **Frontend:** http://localhost:3000 (Microsoft Edge)
- **Backend:** http://localhost:8000 (FastAPI)
- **Database:** Supabase (cloud)

---

## ✨ Test It Out

1. **Register** or **Login** with your email
2. **Set a nickname** (should save successfully now!)
3. **View profile** to see your nickname
4. **Edit profile** to change your nickname

---

## 🔴 If You Get an Error

### "Failed to save nickname"
Make sure:
1. ✅ Backend window shows: `INFO: Application startup complete`
2. ✅ Both PowerShell windows are open
3. ✅ Port 8000 is available (not blocked by firewall)

### "Connection refused" or "Connection timeout"
1. Stop the backend: `CTRL+C` in backend window
2. Kill processes on port 8000:
```powershell
Get-NetTCPConnection -LocalPort 8000 | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```
3. Restart: `.\run_backend_8000.ps1`

### "Cannot find Python" 
Install Python 3.8+: https://www.python.org/downloads/

---

## 💡 Pro Tips

| Key | Action |
|-----|--------|
| `r` | Hot reload (keep state) |
| `R` | Hot restart (reset state) |
| `d` | Detach (keep app running) |
| `q` | Quit app |

---

## 📞 Need Help?

Check [SETUP.md](SETUP.md) for:
- Detailed troubleshooting
- Architecture overview
- Development workflow
- Useful debug commands

---

## 🎯 What Was Fixed

- ✅ Backend server startup script
- ✅ Better error messages when connection fails
- ✅ Improved logging for debugging
- ✅ Documentation for setup

Now the app clearly tells you what's wrong and how to fix it!
