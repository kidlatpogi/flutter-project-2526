-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own scripts" ON public.scripts;
DROP POLICY IF EXISTS "Users can create scripts" ON public.scripts;
DROP POLICY IF EXISTS "Users can update their own scripts" ON public.scripts;
DROP POLICY IF EXISTS "Users can delete their own scripts" ON public.scripts;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS scripts_updated_at_trigger ON public.scripts;
DROP FUNCTION IF EXISTS update_scripts_updated_at();

-- Drop existing table if it exists (start fresh)
DROP TABLE IF EXISTS public.scripts;

-- Create scripts table for storing user practice scripts
CREATE TABLE public.scripts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index on user_id for faster queries
CREATE INDEX scripts_user_id_idx ON public.scripts(user_id);
CREATE INDEX scripts_created_at_idx ON public.scripts(created_at DESC);

-- Enable RLS on scripts table
ALTER TABLE public.scripts ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view their own scripts
CREATE POLICY "Users can view their own scripts"
ON public.scripts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow authenticated users to create scripts
CREATE POLICY "Users can create scripts"
ON public.scripts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow authenticated users to update their own scripts
CREATE POLICY "Users can update their own scripts"
ON public.scripts FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Allow authenticated users to delete their own scripts
CREATE POLICY "Users can delete their own scripts"
ON public.scripts FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_scripts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER scripts_updated_at_trigger
BEFORE UPDATE ON public.scripts
FOR EACH ROW
EXECUTE FUNCTION update_scripts_updated_at();
