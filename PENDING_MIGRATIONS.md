# Pending Database Migrations

Before using the updated features, run these SQL scripts in the Supabase SQL Editor:

## 1. Add Account Status Column (for soft delete)
File: `backend/add_account_status_to_user_profiles.sql`

```sql
-- Add account_status column to user_profiles for soft delete functionality
-- Possible values: 'Active', 'Deleted', 'Suspended'
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS account_status VARCHAR(20) DEFAULT 'Active';

CREATE INDEX IF NOT EXISTS idx_user_profiles_account_status ON public.user_profiles(account_status);

UPDATE public.user_profiles 
SET account_status = 'Active' 
WHERE account_status IS NULL;
```

## 2. Add Detailed Metrics to Sessions Table
File: `backend/add_metrics_to_sessions.sql`

```sql
-- Add new columns for detailed metrics
ALTER TABLE public.sessions
ADD COLUMN IF NOT EXISTS pitch_score FLOAT,
ADD COLUMN IF NOT EXISTS voice_quality_score FLOAT,
ADD COLUMN IF NOT EXISTS pace_score FLOAT,
ADD COLUMN IF NOT EXISTS fluency_score FLOAT,
ADD COLUMN IF NOT EXISTS transcription TEXT;

CREATE INDEX IF NOT EXISTS sessions_confidence_score_idx ON public.sessions(confidence_score);
```

## Order of Execution
1. Run `add_account_status_to_user_profiles.sql` first
2. Run `add_metrics_to_sessions.sql` second

## Notes
- These migrations are backward-compatible and won't break existing data
- The backend code has fallback logic to handle cases where columns don't exist yet
