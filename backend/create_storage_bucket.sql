-- Create a storage bucket for audio recordings in Supabase
-- Run this in the Supabase SQL Editor

-- Storage buckets are managed through the Supabase API, but you can set up policies here

-- RLS policy for the recordings bucket
-- Allow authenticated users to read their own recordings
INSERT INTO storage.buckets (id, name, public)
VALUES ('recordings', 'recordings', false)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload files
CREATE POLICY "Allow authenticated users to upload recordings"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'recordings');

-- Allow authenticated users to read their own session recordings
CREATE POLICY "Allow authenticated users to read their recordings"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'recordings');

-- Allow authenticated users to delete their own recordings
CREATE POLICY "Allow authenticated users to delete their recordings"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'recordings');
