-- Add detailed analysis metrics to sessions table
-- Run in Supabase SQL Editor

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
