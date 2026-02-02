from supabase import create_client
import os
from dotenv import load_dotenv
from pathlib import Path

env_file = Path(__file__).parent / ".env"
load_dotenv(env_file, override=True)

url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_KEY')
client = create_client(url, key)

# List root
print('=== Root Files ===')
files = client.storage.from_('recordings').list()
for f in files:
    print(f'Name: {f["name"]}')
    print(f'  ID: {f.get("id")}')
    print(f'  Metadata: {f.get("metadata")}')

# Try to list the first item if it's a folder
print('\n=== Listing 89d58f42-42b6-4d16-aa9e-a63ea6c06d52 ===')
try:
    sub = client.storage.from_('recordings').list('89d58f42-42b6-4d16-aa9e-a63ea6c06d52')
    print(f'Found {len(sub)} items:')
    for f in sub:
        print(f'  {f["name"]} - {f.get("metadata")}')
except Exception as e:
    print(f'Error: {e}')

# Try direct download tests
print('\n=== Download Tests ===')
test_paths = [
    '89d58f42-42b6-4d16-aa9e-a63ea6c06d52.wav',
    '89d58f42-42b6-4d16-aa9e-a63ea6c06d52/ade7d676-e387-4bd0-9155-ba6eb660513c.wav',
    '89d58f42-42b6-4d16-aa9e-a63ea6c06d52/f9ee8110-1bdf-41e2-a3c7-47ea2cfa66c5.wav',
]

for path in test_paths:
    try:
        data = client.storage.from_('recordings').download(path)
        print(f'✓ {path} - {len(data)} bytes')
    except Exception as e:
        print(f'✗ {path} - {str(e)[:80]}')
