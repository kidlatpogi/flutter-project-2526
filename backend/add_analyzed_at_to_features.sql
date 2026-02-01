-- Add analyzed_at to features table for session ordering
ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_features_analyzed_at ON public.features(analyzed_at);