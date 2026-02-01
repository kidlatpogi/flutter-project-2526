-- Sessions Table for Bigkas
-- Run this SQL in the Supabase SQL Editor to store session summaries

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can create sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can update their own sessions" ON public.sessions;
DROP POLICY IF EXISTS "Users can delete their own sessions" ON public.sessions;

-- Drop existing table if it exists (start fresh)
-- Use CASCADE to remove dependent constraints (e.g., features_session_id_fkey)
DROP TABLE IF EXISTS public.sessions CASCADE;

-- Create sessions table for storing session summaries
CREATE TABLE public.sessions (
  id UUID PRIMARY KEY,
  session_id UUID NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  script_title TEXT,
  duration_seconds INTEGER,
  confidence_score FLOAT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes
CREATE INDEX sessions_user_id_idx ON public.sessions(user_id);
CREATE INDEX sessions_created_at_idx ON public.sessions(created_at DESC);

-- Enable RLS
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view their own sessions
CREATE POLICY "Users can view their own sessions"
ON public.sessions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow authenticated users to create sessions
CREATE POLICY "Users can create sessions"
ON public.sessions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow authenticated users to update their own sessions
CREATE POLICY "Users can update their own sessions"
ON public.sessions FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Allow authenticated users to delete their own sessions
CREATE POLICY "Users can delete their own sessions"
ON public.sessions FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.sessions TO authenticated;
GRANT SELECT ON public.sessions TO anon;
