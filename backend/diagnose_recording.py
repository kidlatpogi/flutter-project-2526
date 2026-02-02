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
print("RECORDING PLAYBACK DIAGNOSTIC TOOL")
print("=" * 70)

# Check backend is running
print("\n[1/4] Checking if backend is running...")
try:
    response = requests.get("http://localhost:8000/health", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print("   ✓ Backend is running")
        print(f"   ✓ Supabase connected: {data.get('supabase_connected', False)}")
        print(f"   ✓ Whisper model loaded: {data.get('whisper_model_loaded', False)}")
        
        if not data.get('supabase_connected'):
            print("\n   ✗ ERROR: Backend not connected to Supabase!")
            print("   → Check that SUPABASE_URL and SUPABASE_KEY are set in .env")
            sys.exit(1)
    else:
        print(f"   ✗ Backend returned status {response.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"   ✗ Cannot reach backend: {e}")
    print("   Make sure backend is running: python backend/main.py")
    sys.exit(1)

# Check debug info
print("\n[2/4] Checking backend configuration...")
try:
    response = requests.get("http://localhost:8000/debug/info", timeout=5)
    if response.status_code == 200:
        data = response.json()
        supabase_url = data['environment']['SUPABASE_URL']
        supabase_key = data['environment']['SUPABASE_KEY']
        
        print(f"   ✓ SUPABASE_URL: {supabase_url}")
        print(f"   ✓ SUPABASE_KEY: {supabase_key}")
        
        if supabase_url != "configured" or supabase_key != "configured":
            print("\n   ✗ ERROR: Missing Supabase configuration!")
            sys.exit(1)
    else:
        print(f"   ✗ Failed with status {response.status_code}")
except Exception as e:
    print(f"   ✗ Error: {e}")
    sys.exit(1)

# Check storage bucket
print("\n[3/4] Checking Supabase Storage...")
try:
    response = requests.get("http://localhost:8000/debug/storage", timeout=5)
    if response.status_code == 200:
        data = response.json()
        buckets = data.get('buckets', [])
        recordings_exists = data.get('recordings_bucket_exists', False)
        files_count = data.get('file_count', 0)
        
        print(f"   ✓ Available buckets: {', '.join(buckets) if buckets else 'none'}")
        
        if recordings_exists:
            print(f"   ✓ 'recordings' bucket exists")
            print(f"   ℹ Files in bucket: {files_count}")
        else:
            print(f"   ✗ 'recordings' bucket NOT FOUND")
            print("\n   TO FIX:")
            print("   1. Go to https://app.supabase.com")
            print("   2. Click 'Storage' in the left sidebar")
            print("   3. Click 'Create new bucket'")
            print("   4. Enter name: recordings")
            print("   5. Uncheck 'Public bucket'")
            print("   6. Click 'Create bucket'")
            print("\n   Then run this script again.")
            sys.exit(1)
    else:
        print(f"   ✗ Failed with status {response.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"   ✗ Error: {e}")
    sys.exit(1)

# Check specific session
print("\n[4/4] Testing a specific recording...")
session_id = input("   Enter a session ID (from the error), or press Enter to skip: ").strip()

if session_id:
    try:
        response = requests.get(f"http://localhost:8000/debug/test-recording/{session_id}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            
            print(f"\n   SESSION: {session_id}")
            session_found = data.get('session_found', False)
            user_id = data.get('user_id', 'unknown')
            attempts = data.get('file_access_attempts', [])
            files_in_bucket = data.get('files_in_bucket', [])
            
            if not session_found:
                print(f"   ✗ Session NOT found in database")
            else:
                print(f"   ✓ Session found")
                print(f"   ℹ User ID: {user_id}")
            
            print(f"\n   FILE ACCESS ATTEMPTS:")
            file_found = False
            for i, attempt in enumerate(attempts, 1):
                path = attempt.get('path')
                status = attempt.get('status')
                if status == 'success':
                    size = attempt.get('size_bytes', 0)
                    print(f"   ✓ [{i}] {path} - SUCCESS ({size} bytes)")
                    file_found = True
                else:
                    error = attempt.get('error', 'Unknown error')
                    print(f"   ✗ [{i}] {path} - FAILED")
                    print(f"       Error: {error[:100]}")
            
            if files_in_bucket:
                print(f"\n   FILES IN BUCKET:")
                for f in files_in_bucket[:10]:
                    print(f"   • {f}")
                if len(files_in_bucket) > 10:
                    print(f"   ... and {len(files_in_bucket) - 10} more")
            
            # Summary and next steps
            print("\n" + "=" * 70)
            print("DIAGNOSIS:")
            print("=" * 70)
            
            if not session_found:
                print("\n✗ ERROR: Session not found!")
                print("\nFIX: Make sure:")
                print("  1. Session ID is correct (copy from error message)")
                print("  2. You completed the analysis")
                print("  3. Check backend logs for errors")
            elif file_found:
                print("\n✓ SUCCESS: Recording file found!")
                print("\nThe file should be playable now.")
                print("If it still doesn't work:")
                print("  1. Try refreshing the browser")
                print("  2. Check browser console (F12) for errors")
                print("  3. Check network tab to see response")
            else:
                print("\n✗ ERROR: Recording file NOT found in storage!")
                print("\nThis means the analysis completed but the file wasn't uploaded.")
                print("\nFIX: Try these steps:")
                print("  1. Create a NEW recording (old ones won't be auto-uploaded)")
                print("  2. Complete the analysis")
                print("  3. Check backend terminal for upload errors")
                print("  4. Run this script again with the new session ID")
        else:
            print(f"   ✗ Failed with status {response.status_code}")
            print(f"   Response: {response.text[:200]}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
else:
    print("   Skipped session check.")

print("\n" + "=" * 70)
print("HELPFUL LINKS:")
print("=" * 70)
print("  Backend logs: Run 'python backend/main.py' in a terminal")
print("  Supabase console: https://app.supabase.com")
print("  Browser console: Press F12 while app is open")
print("=" * 70 + "\n")
