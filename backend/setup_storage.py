#!/usr/bin/env python3
"""
Setup script to automatically create the recordings bucket in Supabase.
Run this once to set up storage: python setup_storage.py
"""

import os
import sys
from pathlib import Path
from datetime import datetime

# Load .env file
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
    else:
        print(f"❌ Error: .env file not found at {env_path}")
        sys.exit(1)
except ImportError:
    print("❌ Error: python-dotenv not installed")
    print("   Run: pip install python-dotenv")
    sys.exit(1)

# Check credentials
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

if not supabase_url or not supabase_key:
    print("❌ Error: SUPABASE_URL or SUPABASE_KEY not set in .env")
    sys.exit(1)

print("=" * 60)
print("SUPABASE STORAGE SETUP")
print("=" * 60)
print(f"\n✓ SUPABASE_URL: {supabase_url[:40]}...")
print(f"✓ SUPABASE_KEY: {supabase_key[:20]}...")

# Import Supabase
try:
    from supabase import create_client
    print("✓ Supabase client imported")
except ImportError:
    print("❌ Error: supabase-py not installed")
    print("   Run: pip install supabase")
    sys.exit(1)

# Connect to Supabase
try:
    db = create_client(supabase_url, supabase_key)
    print("✓ Connected to Supabase")
except Exception as e:
    print(f"❌ Error connecting to Supabase: {e}")
    sys.exit(1)

# Check existing buckets
print("\nChecking existing buckets...")
try:
    buckets = db.storage.list_buckets()
    bucket_names = [b.get('name') for b in buckets] if buckets else []
    print(f"Found {len(bucket_names)} bucket(s): {bucket_names}")
    
    if 'recordings' in bucket_names:
        print("✓ 'recordings' bucket already exists!")
        sys.exit(0)
except Exception as e:
    print(f"⚠️  Could not list buckets: {e}")

# Create recordings bucket
print("\nCreating 'recordings' bucket...")
try:
    # Note: Supabase Python SDK doesn't have a create_bucket method
    # We need to use the REST API directly
    import requests
    
    headers = {
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json"
    }
    
    data = {
        "name": "recordings",
        "public": False
    }
    
    # Construct the API URL
    api_url = supabase_url.rstrip('/') + "/storage/v1/b"
    
    response = requests.post(api_url, json=data, headers=headers, timeout=10)
    
    if response.status_code == 201:
        print("✓ 'recordings' bucket created successfully!")
    elif response.status_code == 400 and "already exists" in response.text:
        print("✓ 'recordings' bucket already exists!")
    elif response.status_code == 400:
        print(f"⚠️  Bucket creation failed: {response.text}")
        print("\nTry creating manually via Supabase Dashboard:")
        print("  1. Go to Storage")
        print("  2. Click 'Create bucket'")
        print("  3. Name: 'recordings'")
        print("  4. Uncheck 'Public bucket'")
    else:
        print(f"❌ Error ({response.status_code}): {response.text}")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Error: {e}")
    print("\nTry creating manually via Supabase Dashboard:")
    print("  1. Go to Storage")
    print("  2. Click 'Create bucket'")
    print("  3. Name: 'recordings'")
    print("  4. Uncheck 'Public bucket'")
    print("  5. Click Create")
    sys.exit(1)

# Verify bucket was created
print("\nVerifying bucket creation...")
try:
    buckets = db.storage.list_buckets()
    bucket_names = [b.get('name') for b in buckets] if buckets else []
    
    if 'recordings' in bucket_names:
        print("✓ Bucket verification successful!")
    else:
        print("⚠️  Bucket not found after creation. It may take a moment to sync.")
except Exception as e:
    print(f"⚠️  Could not verify: {e}")

print("\n" + "=" * 60)
print("SETUP COMPLETE!")
print("=" * 60)
print("\nNext steps:")
print("  1. Restart the backend: Ctrl+C, then 'python backend/main.py'")
print("  2. Create a new practice recording in the app")
print("  3. Click 'Listen to Your Voice'")
print("  4. Audio should now play!")
print("\n" + "=" * 60)
