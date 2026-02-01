-- Add is_active flag to user_profiles for account deactivation
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_user_profiles_is_active ON public.user_profiles(is_active);