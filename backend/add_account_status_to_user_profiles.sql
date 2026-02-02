-- Add account_status column to user_profiles for soft delete functionality
-- Possible values: 'Active', 'Deleted', 'Suspended'
-- Run this SQL in the Supabase SQL Editor

-- Add account_status column
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS account_status VARCHAR(20) DEFAULT 'Active';

-- Create index for filtering by status
CREATE INDEX IF NOT EXISTS idx_user_profiles_account_status ON public.user_profiles(account_status);

-- Update existing records to have 'Active' status if null
UPDATE public.user_profiles 
SET account_status = 'Active' 
WHERE account_status IS NULL;
