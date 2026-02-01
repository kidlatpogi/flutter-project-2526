-- Create avatars bucket for profile pictures
-- Run this in Supabase SQL Editor to create the bucket

-- Note: The avatars bucket needs to be created via the Supabase UI:
-- 1. Go to Storage in your Supabase dashboard
-- 2. Click "Create a new bucket"
-- 3. Name it "avatars"
-- 4. Make it Public
-- 5. Click Create

-- After creating the bucket, ENABLE RLS and add these policies:

-- Allow authenticated users to upload files to their own folder
create policy "Authenticated users can upload avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow anyone to view avatars (bucket is public)
create policy "Anyone can view avatars"
on storage.objects for select
to public
using (bucket_id = 'avatars');

-- Allow users to update their own avatar files
create policy "Users can update their own avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own avatar files
create policy "Users can delete their own avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
