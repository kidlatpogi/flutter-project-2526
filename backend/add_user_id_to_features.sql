-- Add user_id to features table for per-user queries
ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_features_user_id ON public.features(user_id);
