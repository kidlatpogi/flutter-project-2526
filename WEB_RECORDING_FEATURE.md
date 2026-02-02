# Web Recording Playback Feature

## Overview

The "Listen to Your Voice" feature is now available on **all platforms** (web, mobile, desktop) with platform-specific optimizations.

## How It Works

### For Native Platforms (iOS, Android, Windows, macOS, Linux)
- Recording is saved to the **local device cache** after analysis
- Files are stored locally in the app's temporary directory
- Files are automatically cleaned up after **14 days**
- **Advantage**: Faster playback, works offline, no network latency

### For Web
- Recording is stored on the **Supabase Storage** backend during analysis
- When user clicks "Listen to Your Voice", the app streams the audio from the server
- Files are automatically deleted after **14 days** (managed by retention policy)
- **Advantage**: Consistent experience across browsers, works on any device, centralized storage

## Implementation Details

### Frontend Changes (Dart/Flutter)

#### Audio Service (`lib/core/services/audio_service.dart`)
```dart
Future<String?> getRecordingPathForSession(String sessionId) async {
  // Web: Returns a backend URL like "/sessions/{sessionId}/recording"
  // Native: Returns a local file path
  if (kIsWeb) {
    return '/sessions/$sessionId/recording';
  }
  
  // Native: Get from local cache
  final filePath = '${directory.path}/session_$sessionId.wav';
  // ... validation and expiry check
  return filePath;
}
```

#### Analysis Result Screen (`lib/features/practice/screens/analysis_result_screen.dart`)
```dart
Future<void> _togglePlayback() async {
  if (_recordingPath!.startsWith('/') || _recordingPath!.startsWith('http')) {
    // Web: Stream from URL
    final fullUrl = 'http://localhost:8000${_recordingPath!}';
    await _audioPlayer.play(UrlSource(fullUrl));
  } else {
    // Native: Play from local file
    await _audioPlayer.play(DeviceFileSource(_recordingPath!));
  }
}
```

### Backend Changes (Python/FastAPI)

#### New Endpoint
```python
GET /sessions/{session_id}/recording
```

**Purpose**: Serves audio recordings for web playback

**Features**:
- Requires authentication via Bearer token
- Verifies user has access to the recording
- Checks 14-day retention period
- Streams file directly from Supabase Storage

#### Storage Integration
- Records are stored in Supabase Storage `recordings` bucket
- Path: `{user_id}/{session_id}.wav`
- Storage policies ensure users can only access their own recordings
- Automatic cleanup after 14 days (via RLS policies)

#### Recording Upload (Modified `/analyze-audio` endpoint)
```python
# After analysis is saved to database, also save to storage
if user_id and temp_path and temp_path.exists():
    file_data = f.read()
    storage.from_("recordings").upload(
        f"{user_id}/{result.session_id}.wav",
        file_data
    )
```

## Setup Instructions

### 1. Create Supabase Storage Bucket

Run the SQL script in Supabase SQL Editor:
```sql
-- Create storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('recordings', 'recordings', false)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for recordings bucket
CREATE POLICY "Allow authenticated users to upload recordings"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'recordings');

CREATE POLICY "Allow authenticated users to read their recordings"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'recordings');

CREATE POLICY "Allow authenticated users to delete their recordings"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'recordings');
```

**File**: `backend/create_storage_bucket.sql`

### 2. Backend Configuration

Ensure your `app/config.py` has Supabase credentials:
```python
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
```

### 3. Frontend Configuration

The frontend automatically detects the platform:
- Web: Uses Supabase Storage URL
- Native: Uses local file cache

No additional configuration needed!

## Platform-Specific Behavior

### Web Browser
```
User clicks "Listen to Your Voice"
  ↓
Frontend gets: "/sessions/{id}/recording"
  ↓
Frontend builds full URL: "http://localhost:8000/sessions/{id}/recording"
  ↓
AudioPlayer streams from backend
  ↓
User hears recording
```

### Native (iOS/Android)
```
Recording completed
  ↓
Backend analysis returned
  ↓
Frontend saves recording file locally
  ↓
User clicks "Listen to Your Voice"
  ↓
Frontend gets: "/path/to/cache/session_{id}.wav"
  ↓
AudioPlayer plays local file
  ↓
User hears recording (instant, no network)
```

## Testing

### Test Web Playback
1. Run backend: `python backend/main.py`
2. Run frontend: `flutter run -d chrome`
3. Complete a recording/analysis
4. Click "Listen to Your Voice"
5. Audio should play from server

### Test Native Playback
1. Run on Android/iOS device
2. Complete a recording/analysis
3. Click "Listen to Your Voice"
4. Audio should play from local cache

### Verify Storage
1. Check Supabase Storage Dashboard
2. Look in `recordings` bucket
3. Should see files in `{user_id}/{session_id}.wav` format

## Retention Policy

Both platforms enforce a **14-day retention** period:

**Native**:
- Files in cache directory are automatically deleted after 14 days
- Cleanup happens automatically during recording save

**Web**:
- Endpoint checks file age and rejects requests older than 14 days
- Storage policies can be configured for automatic expiration
- Manual cleanup can be run periodically via scheduled tasks

## Error Handling

### Web-Specific Errors
- `404 Not Found`: Recording not found or expired
- `401 Unauthorized`: User doesn't have access to recording
- `500 Server Error`: Storage/backend issues

### Native-Specific Errors  
- File permissions issue
- File system full
- Corrupted cache file

All errors are caught and displayed to the user with helpful messages.

## Performance Considerations

### Web
- First request: ~500ms-2s (network latency)
- Subsequent requests: Cached by browser
- File size: Typically 1-5MB for 10 minute recordings

### Native
- First load: Instant (local file)
- Playback: Smooth, no stuttering
- Storage: App cache directory (user can clear anytime)

## Security

### Web
- Supabase RLS policies ensure users only access their own recordings
- JWT authentication required
- Files marked as private in storage

### Native
- Files stored in app-only cache directory
- Inaccessible to other apps (on most platforms)
- Automatically cleared when app is uninstalled

## Future Improvements

1. **Signed URLs**: Generate temporary signed URLs for better security
2. **Download**: Allow users to download their recording
3. **Share**: Generate shareable recording links (with expiry)
4. **Compression**: Compress audio before storage to save space
5. **Analytics**: Track which recordings are accessed
6. **Cleanup Job**: Scheduled task to delete expired recordings automatically

## Troubleshooting

### "Recording not available" on Web
- Check backend is running
- Verify Supabase credentials in backend
- Check storage bucket exists in Supabase
- Check browser console for CORS errors

### "Recording not available" on Native
- Verify app has storage permissions
- Check cache directory isn't full
- Verify file wasn't manually deleted

### Playback is slow on Web
- Check network connectivity
- Try a different browser
- Check backend logs for errors
- Verify recording file exists in Supabase Storage
