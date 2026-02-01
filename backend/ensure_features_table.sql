-- Ensure features table has required columns and policies
-- Run in Supabase SQL Editor

-- Add missing columns
ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.features
ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ DEFAULT NOW();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_features_user_id ON public.features(user_id);
CREATE INDEX IF NOT EXISTS idx_features_analyzed_at ON public.features(analyzed_at);

-- Enable RLS and allow all operations (adjust for production)
ALTER TABLE public.features ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all operations on features" ON public.features;
CREATE POLICY "Allow all operations on features" ON public.features
    FOR ALL
    USING (true)
    WITH CHECK (true);

GRANT ALL ON public.features TO authenticated;
GRANT ALL ON public.features TO anon;
