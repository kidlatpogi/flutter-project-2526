from supabase import create_client
import os
from dotenv import load_dotenv
from pathlib import Path

env_file = Path(__file__).parent / ".env"
load_dotenv(env_file, override=True)

url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_KEY')
client = create_client(url, key)

# Check database for recent sessions
result = client.table('features').select('session_id, user_id, created_at').order('created_at', desc=True).limit(5).execute()
print('Recent 5 sessions in database:')
for s in result.data:
    print(f"  {s['session_id'][:8]}... - user_id: {s.get('user_id')} - {s.get('created_at')}")

# Check if user_id exists for the file we found
user_id_to_check = '89d58f42-42b6-4d16-aa9e-a63ea6c06d52'
print(f'\nLooking for user_id {user_id_to_check[:8]}...:')
try:
    users = client.table('user_profiles').select('*').eq('id', user_id_to_check).execute()
    print(f'  Found: {len(users.data)} profiles')
except Exception as e:
    print(f'  Error: {e}')

# Check sessions with that user_id
print(f'\nLooking for sessions with user_id {user_id_to_check[:8]}...:')
try:
    sessions = client.table('features').select('session_id').eq('user_id', user_id_to_check).limit(10).execute()
    print(f'  Found {len(sessions.data)} sessions')
    for s in sessions.data[:3]:
        print(f'    {s["session_id"][:8]}...')
except Exception as e:
    print(f'  Error: {e}')
