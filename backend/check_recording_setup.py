#!/usr/bin/env python3
"""
Quick diagnostic script to check recording playback setup.
Run this from the backend directory: python check_recording_setup.py
"""

import os
import sys
import asyncio
from datetime import datetime

# Check environment
print("=" * 60)
print("RECORDING PLAYBACK SETUP DIAGNOSTIC")
print("=" * 60)

print("\n1. Checking environment variables...")
required_env = ["SUPABASE_URL", "SUPABASE_KEY"]
missing = []
for env_var in required_env:
    value = os.getenv(env_var)
    if value:
        # Show only first/last 10 chars for security
        masked = f"{value[:10]}...{value[-10:]}" if len(value) > 20 else "***"
        print(f"   ✓ {env_var}: {masked}")
    else:
        print(f"   ✗ {env_var}: NOT SET")
        missing.append(env_var)

if missing:
    print(f"\n⚠️  Missing environment variables: {', '.join(missing)}")
    print("   Add these to backend/.env and restart the backend.")

print("\n2. Checking Supabase connection...")
try:
    from app.database import get_supabase
    
    async def check_connection():
        try:
            db = await get_supabase()
            print("   ✓ Connected to Supabase")
            
            # Check storage
            print("\n3. Checking storage buckets...")
            storage = db.storage
            buckets = storage.list_buckets()
            bucket_names = [b.get('name') for b in buckets]
            
            if bucket_names:
                print(f"   ✓ Found {len(bucket_names)} bucket(s):")
                for name in bucket_names:
                    print(f"     - {name}")
                    if name == "recordings":
                        print("       ✓ 'recordings' bucket exists!")
            else:
                print("   ✗ No buckets found")
                print("   ⚠️  Need to create 'recordings' bucket in Supabase Storage")
            
            # Check if recordings bucket exists
            if 'recordings' not in bucket_names:
                print("\n⚠️  ACTION REQUIRED:")
                print("   1. Go to Supabase Dashboard → Storage")
                print("   2. Click 'Create bucket'")
                print("   3. Name it: 'recordings'")
                print("   4. Uncheck 'Public bucket'")
                print("   5. Click Create")
                
            return bucket_names
        except Exception as e:
            print(f"   ✗ Connection failed: {e}")
            return None
    
    buckets = asyncio.run(check_connection())
    
except Exception as e:
    print(f"   ✗ Error checking Supabase: {e}")
    print("   Check your .env file for correct credentials")

print("\n4. Checking backend API...")
try:
    import requests
    response = requests.get("http://localhost:8000/health", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print(f"   ✓ Backend is running")
        print(f"   ✓ Supabase connected: {data.get('supabase_connected', False)}")
        print(f"   ✓ Whisper model loaded: {data.get('whisper_model_loaded', False)}")
    else:
        print(f"   ✗ Backend returned status {response.status_code}")
except Exception as e:
    print(f"   ✗ Cannot reach backend: {e}")
    print("   Make sure backend is running: python backend/main.py")

print("\n5. Checking storage debug endpoint...")
try:
    import requests
    response = requests.get("http://localhost:8000/debug/storage", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print(f"   ✓ Debug endpoint response:")
        for key, value in data.items():
            print(f"     - {key}: {value}")
    else:
        print(f"   ✗ Debug endpoint failed with status {response.status_code}")
except Exception as e:
    print(f"   ✗ Cannot reach debug endpoint: {e}")

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)

if missing:
    print("❌ Missing configuration. Follow these steps:")
    print("   1. Set SUPABASE_URL and SUPABASE_KEY in backend/.env")
    print("   2. Restart the backend")
    print("   3. Run this script again")
else:
    print("✅ Basic setup looks good!")
    print("\nNext steps:")
    print("   1. Make sure 'recordings' bucket exists in Supabase Storage")
    print("   2. Create a new recording in the app")
    print("   3. Click 'Listen to Your Voice' button")
    print("   4. Check browser console for errors")

print("\nFor detailed troubleshooting, see: TROUBLESHOOT_RECORDING.md")
print("=" * 60)
