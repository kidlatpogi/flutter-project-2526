#!/usr/bin/env python3
"""
Diagnostic script to troubleshoot recording playback issues.
Run this: python backend/diagnose_recording.py
"""

import requests
import sys
from pathlib import Path

# Load .env
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / ".env"
    if env_path.exists():
        import os
        load_dotenv(env_path)
except:
    pass

print("=" * 70)
print("RECORDING PLAYBACK DIAGNOSTIC")
print("=" * 70)

# Check backend is running
print("\n1. Checking if backend is running...")
try:
    response = requests.get("http://localhost:8000/health", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print("   ✓ Backend is running")
        print(f"   ✓ Supabase connected: {data.get('supabase_connected', False)}")
        print(f"   ✓ Whisper model loaded: {data.get('whisper_model_loaded', False)}")
    else:
        print(f"   ✗ Backend returned status {response.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"   ✗ Cannot reach backend: {e}")
    print("   Make sure backend is running: python backend/main.py")
    sys.exit(1)

# Check debug info
print("\n2. Checking backend configuration...")
try:
    response = requests.get("http://localhost:8000/debug/info", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print(f"   ✓ SUPABASE_URL: {data['environment']['SUPABASE_URL']}")
        print(f"   ✓ SUPABASE_KEY: {data['environment']['SUPABASE_KEY']}")
    else:
        print(f"   ✗ Failed with status {response.status_code}")
except Exception as e:
    print(f"   ✗ Error: {e}")

# Ask for session ID
print("\n3. Testing a specific recording...")
session_id = input("   Enter a session ID to test (or press Enter to skip): ").strip()

if session_id:
    try:
        response = requests.get(f"http://localhost:8000/debug/session/{session_id}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"\n   Session ID: {session_id}")
            print(f"   ✓ Session found: {data.get('session_found', False)}")
            print(f"   ✓ User ID: {data.get('session_user_id', 'N/A')}")
            print(f"   ✓ Recordings bucket exists: {data.get('recordings_bucket_exists', False)}")
            print(f"   ✓ File exists: {data.get('file_exists', False)}")
            
            if data.get('file_error'):
                print(f"   ✗ File error: {data.get('file_error')}")
            
            # Summary
            print("\n   SUMMARY:")
            if not data.get('session_found'):
                print("   ✗ Session not found in database")
            elif not data.get('recordings_bucket_exists'):
                print("   ✗ Recordings bucket NOT created in Supabase Storage")
                print("   → Go to https://app.supabase.com → Storage → Create bucket 'recordings'")
            elif not data.get('file_exists'):
                print("   ✗ Recording file not found in storage")
                print("   → Try creating a NEW recording (old ones won't be uploaded)")
            else:
                print("   ✓ Session, bucket, and file all exist!")
                print("   → The issue might be with network/permissions")
        else:
            print(f"   ✗ Failed with status {response.status_code}")
    except Exception as e:
        print(f"   ✗ Error: {e}")

print("\n" + "=" * 70)
print("WHAT TO CHECK NEXT:")
print("=" * 70)
print("""
1. ✓ Check backend terminal for error messages
2. ✓ Verify 'recordings' bucket exists in Supabase Storage
3. ✓ Create a NEW recording (old ones won't be uploaded)
4. ✓ Check browser console (F12) for network errors
5. ✓ Check backend logs show: "Recording uploaded successfully"

For detailed troubleshooting, see: TROUBLESHOOT_RECORDING.md
""")
print("=" * 70)
