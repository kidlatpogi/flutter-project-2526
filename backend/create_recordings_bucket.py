#!/usr/bin/env python3
"""
Quick script to create the 'recordings' storage bucket in Supabase.
Run this: python backend/create_recordings_bucket.py
"""

import os
import sys
from pathlib import Path

# Load .env
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / ".env"
    if env_path.exists():
        load_dotenv(env_path, override=True)
        print(f"✓ Loaded .env from: {env_path}")
except:
    pass

# Check environment
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("✗ ERROR: SUPABASE_URL or SUPABASE_KEY not found in .env")
    sys.exit(1)

print(f"✓ SUPABASE_URL: {SUPABASE_URL[:30]}...")
print(f"✓ SUPABASE_KEY: {SUPABASE_KEY[:20]}...")

# Try to create bucket
try:
    from supabase import create_client
    
    print("\n[Creating 'recordings' bucket...]")
    
    # Create Supabase client (using service role key for admin access)
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    try:
        # Try to create the bucket
        response = supabase.storage.create_bucket("recordings", options={"public": False})
        print("✓ Bucket 'recordings' created successfully!")
        print(f"  Response: {response}")
    except Exception as e:
        error_msg = str(e)
        
        # Check if bucket already exists
        if "already exists" in error_msg.lower() or "exists" in error_msg.lower():
            print("✓ Bucket 'recordings' already exists!")
        else:
            print(f"✗ Error: {error_msg}")
            
            # Try alternative: list buckets
            try:
                buckets = supabase.storage.list_buckets()
                bucket_names = [b.get('name') for b in buckets]
                print(f"\n  Available buckets: {', '.join(bucket_names) if bucket_names else 'none'}")
                
                if 'recordings' not in bucket_names:
                    print("\n  Bucket still doesn't exist. Try creating it manually:")
                    print("  1. Go to https://app.supabase.com")
                    print("  2. Click 'Storage' → 'Create new bucket'")
                    print("  3. Name: recordings (lowercase)")
                    print("  4. Uncheck 'Public bucket'")
                    sys.exit(1)
            except Exception as e2:
                print(f"  Could not list buckets: {e2}")
                sys.exit(1)
    
    # Verify bucket exists
    try:
        buckets = supabase.storage.list_buckets()
        bucket_names = [b.get('name') for b in buckets]
        
        if 'recordings' in bucket_names:
            print(f"\n✓ SUCCESS: 'recordings' bucket exists and is ready!")
            print(f"  Total buckets: {len(bucket_names)}")
        else:
            print(f"\n✗ ERROR: Bucket creation may have failed")
            print(f"  Available buckets: {', '.join(bucket_names)}")
            sys.exit(1)
    except Exception as e:
        print(f"✓ Bucket appears to be created (cannot verify list)")

except ImportError:
    print("✗ ERROR: supabase-py not installed")
    print("  Run: pip install supabase")
    sys.exit(1)
except Exception as e:
    print(f"✗ ERROR: {e}")
    sys.exit(1)

print("\n" + "="*60)
print("Now run the diagnostic to verify:")
print("  python backend/diagnose_recording.py")
print("="*60)
