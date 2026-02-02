# Pending Database Migrations

Before using the updated features, run these SQL scripts in the Supabase SQL Editor:

## 1. Add Account Status Column (for soft delete)
File: `backend/add_account_status_to_user_profiles.sql`

```sql
-- Add account_status column to user_profiles for soft delete functionality
-- Possible values: 'Active', 'Deleted', 'Suspended'
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS account_status VARCHAR(20) DEFAULT 'Active';

CREATE INDEX IF NOT EXISTS idx_user_profiles_account_status ON public.user_profiles(account_status);

UPDATE public.user_profiles 
SET account_status = 'Active' 
WHERE account_status IS NULL;
```

## 2. Add Detailed Metrics to Sessions Table
File: `backend/add_metrics_to_sessions.sql`

```sql
-- Add new columns for detailed metrics
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS pitch_score FLOAT,
ADD COLUMN IF NOT EXISTS voice_quality_score FLOAT,
ADD COLUMN IF NOT EXISTS pace_score FLOAT,
ADD COLUMN IF NOT EXISTS fluency_score FLOAT,
ADD COLUMN IF NOT EXISTS transcription TEXT;

CREATE INDEX IF NOT EXISTS sessions_confidence_score_idx ON public.sessions(confidence_score);
```

## 3. Add Detailed Metrics to Features Table
File: `backend/add_metrics_to_features.sql`

```sql
-- Add missing metrics columns to features table
ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS pitch_mean FLOAT,
ADD COLUMN IF NOT EXISTS pitch_std FLOAT,
ADD COLUMN IF NOT EXISTS jitter_local FLOAT,
ADD COLUMN IF NOT EXISTS shimmer_local FLOAT,
ADD COLUMN IF NOT EXISTS harmonics_to_noise_ratio FLOAT,
ADD COLUMN IF NOT EXISTS wpm FLOAT,
ADD COLUMN IF NOT EXISTS filler_count INTEGER,
ADD COLUMN IF NOT EXISTS filler_words_found TEXT[],
ADD COLUMN IF NOT EXISTS total_words INTEGER,
ADD COLUMN IF NOT EXISTS articulation_rate FLOAT,
ADD COLUMN IF NOT EXISTS total_pause_duration FLOAT,
ADD COLUMN IF NOT EXISTS pause_count INTEGER,
ADD COLUMN IF NOT EXISTS pause_ratio FLOAT,
ADD COLUMN IF NOT EXISTS average_pause_duration FLOAT,
ADD COLUMN IF NOT EXISTS longest_pause FLOAT,
ADD COLUMN IF NOT EXISTS pitch_score FLOAT,
ADD COLUMN IF NOT EXISTS fluency_score FLOAT,
ADD COLUMN IF NOT EXISTS voice_quality_score FLOAT,
ADD COLUMN IF NOT EXISTS pace_score FLOAT;

CREATE INDEX IF NOT EXISTS idx_features_pitch_score ON public.features(pitch_score);
CREATE INDEX IF NOT EXISTS idx_features_fluency_score ON public.features(fluency_score);
CREATE INDEX IF NOT EXISTS idx_features_voice_quality_score ON public.features(voice_quality_score);
CREATE INDEX IF NOT EXISTS idx_features_pace_score ON public.features(pace_score);
```

## 4. Add Detailed Metrics to Sessions Table (Full)
File: `backend/add_metrics_to_sessions_full.sql`

```sql
-- Add detailed analysis metrics to sessions table
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS pitch_mean FLOAT,
ADD COLUMN IF NOT EXISTS pitch_std FLOAT,
ADD COLUMN IF NOT EXISTS jitter_local FLOAT,
ADD COLUMN IF NOT EXISTS shimmer_local FLOAT,
ADD COLUMN IF NOT EXISTS harmonics_to_noise_ratio FLOAT,
ADD COLUMN IF NOT EXISTS wpm FLOAT,
ADD COLUMN IF NOT EXISTS filler_count INTEGER,
ADD COLUMN IF NOT EXISTS filler_words_found TEXT[],
ADD COLUMN IF NOT EXISTS total_words INTEGER,
ADD COLUMN IF NOT EXISTS articulation_rate FLOAT,
ADD COLUMN IF NOT EXISTS total_pause_duration FLOAT,
ADD COLUMN IF NOT EXISTS pause_count INTEGER,
ADD COLUMN IF NOT EXISTS pause_ratio FLOAT,
ADD COLUMN IF NOT EXISTS average_pause_duration FLOAT,
ADD COLUMN IF NOT EXISTS longest_pause FLOAT,
ADD COLUMN IF NOT EXISTS transcription TEXT;

CREATE INDEX IF NOT EXISTS sessions_pitch_score_idx ON public.sessions(pitch_score);
CREATE INDEX IF NOT EXISTS sessions_fluency_score_idx ON public.sessions(fluency_score);
CREATE INDEX IF NOT EXISTS sessions_voice_quality_score_idx ON public.sessions(voice_quality_score);
CREATE INDEX IF NOT EXISTS sessions_pace_score_idx ON public.sessions(pace_score);
```

## Order of Execution
1. Run `add_account_status_to_user_profiles.sql` first
2. Run `add_metrics_to_sessions.sql` second
3. Run `add_metrics_to_features.sql` third
4. Run `add_metrics_to_sessions_full.sql` fourth

## Notes
- These migrations are backward-compatible and won't break existing data
- The backend code has fallback logic to handle cases where columns don't exist yet
