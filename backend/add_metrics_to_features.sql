-- Add missing metrics columns to features table
-- Run in Supabase SQL Editor

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
