-- Update Sessions Table to include detailed metrics
-- Run this SQL in the Supabase SQL Editor

-- Add new columns for detailed metrics
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS pitch_score FLOAT,
ADD COLUMN IF NOT EXISTS voice_quality_score FLOAT,
ADD COLUMN IF NOT EXISTS pace_score FLOAT,
ADD COLUMN IF NOT EXISTS fluency_score FLOAT,
ADD COLUMN IF NOT EXISTS transcription TEXT;

-- Create index for fetching sessions with metrics
CREATE INDEX IF NOT EXISTS sessions_confidence_score_idx ON public.sessions(confidence_score);
