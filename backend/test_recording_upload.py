#!/usr/bin/env python3
"""
Test script to verify recording upload works.
"""

import os
import sys
import requests
from pathlib import Path

# Load env
from dotenv import load_dotenv
env_path = Path(__file__).parent / ".env"
load_dotenv(env_path, override=True)

BACKEND_URL = "http://localhost:8000"

print("=" * 70)
print("RECORDING UPLOAD TEST")
print("=" * 70)

# Check backend
print("\n[1] Checking backend...")
try:
    response = requests.get(f"{BACKEND_URL}/health", timeout=5)
    if response.status_code == 200:
        print("✓ Backend running")
    else:
        print(f"✗ Backend returned {response.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"✗ Backend not responding: {e}")
    sys.exit(1)

# Check storage bucket
print("\n[2] Checking storage...")
try:
    response = requests.get(f"{BACKEND_URL}/debug/storage", timeout=5)
    data = response.json()
    if data.get("recordings_bucket_exists"):
        print(f"✓ Recordings bucket exists")
        print(f"  Files: {data.get('file_count', 0)}")
    else:
        print("✗ Bucket doesn't exist")
        sys.exit(1)
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)

# Create a test audio file (1 second of silence)
print("\n[3] Creating test audio file...")
try:
    import numpy as np
    import wave
    
    # Generate 1 second of silence at 16kHz
    sample_rate = 16000
    duration = 1  # seconds
    samples = np.zeros(sample_rate * duration, dtype=np.int16)
    
    # Write WAV file
    test_audio_path = Path("/tmp/test_audio.wav")
    with wave.open(str(test_audio_path), 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)   # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(samples.tobytes())
    
    print(f"✓ Created test audio: {test_audio_path} ({test_audio_path.stat().st_size} bytes)")
except Exception as e:
    print(f"✗ Error creating audio: {e}")
    # Try to use a minimal WAV file instead
    test_audio_path = Path("/tmp/test_audio.wav")
    with open(test_audio_path, 'wb') as f:
        # Minimal WAV header + 1 byte of silence
        wav_header = b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x11\x56\x00\x00\x22\xb0\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00'
        f.write(wav_header)
    print(f"✓ Created minimal test audio: {test_audio_path}")

# Send to backend
print("\n[4] Sending to backend...")
try:
    with open(test_audio_path, 'rb') as f:
        files = {'audio': ('test_audio.wav', f, 'audio/wav')}
        data = {'save_to_db': 'true'}
        
        response = requests.post(
            f"{BACKEND_URL}/analyze-audio",
            files=files,
            data=data,
            timeout=60
        )
    
    if response.status_code == 200:
        result = response.json()
        session_id = result.get('session_id')
        print(f"✓ Analysis completed")
        print(f"  Session ID: {session_id}")
        print(f"  Confidence: {result.get('confidence_score', 'N/A')}")
        
        # Wait a moment for async upload
        import time
        print("\n[5] Waiting for upload to complete (5 seconds)...")
        time.sleep(5)
        
        # Check if file was uploaded
        print("\n[6] Checking if file was uploaded...")
        response = requests.get(f"{BACKEND_URL}/debug/test-recording/{session_id}", timeout=5)
        if response.status_code == 200:
            data = response.json()
            attempts = data.get('file_access_attempts', [])
            
            file_found = False
            for attempt in attempts:
                if attempt.get('status') == 'success':
                    print(f"✓ File found: {attempt.get('path')}")
                    file_found = True
                    break
            
            if not file_found:
                print("✗ File NOT found in storage")
                print(f"  Attempts: {attempts}")
            else:
                print("\n✓✓✓ SUCCESS! Recording uploaded and can be retrieved!")
        else:
            print(f"✗ Error checking file: {response.status_code}")
    else:
        print(f"✗ Analysis failed: {response.status_code}")
        print(f"  Response: {response.text[:200]}")
except Exception as e:
    print(f"✗ Error: {e}", exc_info=True)
finally:
    # Clean up
    if test_audio_path.exists():
        test_audio_path.unlink()

print("\n" + "=" * 70)
