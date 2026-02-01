-- Backfill user_id for existing features rows
-- Replace <USER_ID> with your Supabase auth user id
UPDATE public.features
SET user_id = '9a0f7b7d-8cfa-45f5-8197-02157a3095a4'
WHERE user_id IS NULL;
