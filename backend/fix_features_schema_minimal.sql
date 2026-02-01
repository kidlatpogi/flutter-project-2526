-- Minimal schema fixes for existing features table
-- Run in Supabase SQL Editor

ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS audio_duration FLOAT;

ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS confidence_score FLOAT;

ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_features_user_id ON public.features(user_id);
CREATE INDEX IF NOT EXISTS idx_features_analyzed_at ON public.features(analyzed_at);
CREATE INDEX IF NOT EXISTS idx_features_confidence_score ON public.features(confidence_score);
