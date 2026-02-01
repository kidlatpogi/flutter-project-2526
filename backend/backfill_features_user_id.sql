-- Backfill user_id for existing features rows
-- Replace <USER_ID> with your Supabase auth user id
UPDATE public.features
SET user_id = '<USER_ID>'
WHERE user_id IS NULL;
