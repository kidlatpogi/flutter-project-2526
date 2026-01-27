# Bigkas Backend API

A FastAPI backend for public speaking assessment. This API analyzes audio recordings to provide confidence metrics and feedback on speaking performance.

## Features

- **Speech-to-Text**: Transcription using OpenAI Whisper (local model)
- **Acoustic Analysis**: Pitch, jitter, shimmer, and harmonics-to-noise ratio extraction using Praat-Parselmouth
- **Fluency Metrics**: Words per minute (WPM) and filler word detection
- **Pause Analysis**: Detection and measurement of pauses using librosa
- **Confidence Scoring**: Weighted algorithm generating a 0-100 speaking confidence score
- **Database Storage**: Results stored in Supabase (PostgreSQL)

## Tech Stack

- **Framework**: FastAPI
- **Audio Processing**: praat-parselmouth, librosa
- **Speech Recognition**: OpenAI Whisper
- **Database**: Supabase
- **Validation**: Pydantic

## Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

> **Note**: Installing Whisper may require additional system dependencies. On Windows, you may need to install ffmpeg.

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your Supabase credentials:

```bash
cp .env.example .env
```

Edit `.env`:
```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
WHISPER_MODEL_SIZE=base
```

### 3. Set Up Database

Run the SQL schema in your Supabase SQL Editor:

```bash
# Copy contents of supabase_schema.sql and run in Supabase Dashboard > SQL Editor
```

### 4. Run the Server

```bash
# Development
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Or simply
python main.py
```

## API Endpoints

### Health Check
```
GET /health
```
Returns API and dependency status.

### Analyze Audio
```
POST /analyze-audio
```
Upload an audio file (WAV or MP3) for analysis.

**Parameters:**
- `audio`: Audio file (multipart/form-data)
- `save_to_db`: Boolean to save results to database (default: true)

**Response:**
```json
{
  "session_id": "uuid",
  "transcription": "transcribed text...",
  "audio_duration": 30.5,
  "audio_metrics": {
    "pitch_mean": 150.5,
    "pitch_std": 25.3,
    "jitter_local": 0.8,
    "shimmer_local": 3.2,
    "harmonics_to_noise_ratio": 18.5
  },
  "fluency_metrics": {
    "words_per_minute": 130.5,
    "filler_count": 5,
    "filler_words_found": ["um", "uh"],
    "total_words": 150,
    "articulation_rate": 145.2
  },
  "pause_metrics": {
    "total_pause_duration": 12.5,
    "pause_count": 8,
    "pause_ratio": 0.15,
    "average_pause_duration": 1.56,
    "longest_pause": 3.2
  },
  "confidence_score": {
    "overall_score": 78.5,
    "pitch_score": 82.0,
    "fluency_score": 75.0,
    "voice_quality_score": 80.0,
    "pace_score": 77.0
  },
  "analyzed_at": "2024-01-15T10:30:00Z"
}
```

### Retrieve Analysis
```
GET /analysis/{session_id}
```
Retrieve a previously stored analysis by session ID.

## Scoring Algorithm

The confidence score (0-100) is calculated using weighted components:

| Component | Weight | Description |
|-----------|--------|-------------|
| Pitch Stability | 20% | Appropriate variation (not monotone, not erratic) |
| Voice Quality | 25% | Low jitter/shimmer, high HNR |
| Fluency | 30% | Few filler words |
| Pace | 25% | Optimal WPM (~130) and pause ratio (~20%) |

### Optimal Ranges

- **WPM**: 100-160 (optimal: 130)
- **Jitter**: < 1.0% (excellent), < 1.5% (acceptable)
- **Shimmer**: < 5.0% (excellent), < 7.0% (acceptable)
- **HNR**: > 20 dB (good), > 25 dB (excellent)
- **Pause Ratio**: 10-35% (optimal: 20%)

## Project Structure

```
backend/
├── main.py                 # FastAPI application
├── requirements.txt        # Python dependencies
├── .env                    # Environment variables
├── supabase_schema.sql     # Database schema
├── README.md               # This file
└── app/
    ├── __init__.py
    ├── config.py           # Settings and configuration
    ├── models.py           # Pydantic models
    ├── database.py         # Supabase client
    └── analysis/
        ├── __init__.py
        ├── transcription.py    # Whisper transcription
        ├── acoustics.py        # Praat analysis
        ├── fluency.py          # WPM and fillers
        ├── pauses.py           # Pause detection
        ├── scoring.py          # Confidence scoring
        └── pipeline.py         # Analysis orchestration
```

## Development

### Running Tests
```bash
pytest tests/
```

### API Documentation
Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## License

MIT License - Capstone Project 2024
