#!/usr/bin/env python
"""Start the backend server"""
import sys
import os
import uvicorn

# Ensure we're in the right directory  
backend_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backend')
os.chdir(backend_dir)
sys.path.insert(0, backend_dir)

print(f"Working directory: {os.getcwd()}")
print(f"Python path: {sys.path[:2]}")

# Start uvicorn
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False, log_level="info")

