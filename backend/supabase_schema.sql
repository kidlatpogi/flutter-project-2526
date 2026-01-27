-- Bigkas Database Schema for Supabase
-- Run this SQL in the Supabase SQL Editor to create the required table

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create the features table for storing analysis results
CREATE TABLE IF NOT EXISTS features (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Session identifier (from the API)
    session_id UUID NOT NULL UNIQUE,
    
    -- Transcription
    transcription TEXT,
    audio_duration FLOAT,
    
    -- Audio/Acoustic metrics
    pitch_mean FLOAT,
    pitch_std FLOAT,
    jitter_local FLOAT,
    shimmer_local FLOAT,
    harmonics_to_noise_ratio FLOAT,
    
    -- Fluency metrics
    wpm FLOAT,
    filler_count INTEGER,
    filler_words_found TEXT[],  -- Array of filler words detected
    total_words INTEGER,
    articulation_rate FLOAT,
    
    -- Pause metrics
    total_pause_duration FLOAT,
    pause_count INTEGER,
    pause_ratio FLOAT,
    average_pause_duration FLOAT,
    longest_pause FLOAT,
    
    -- Confidence scores
    confidence_score FLOAT,
    pitch_score FLOAT,
    fluency_score FLOAT,
    voice_quality_score FLOAT,
    pace_score FLOAT,
    
    -- Timestamps
    analyzed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_features_session_id ON features(session_id);
CREATE INDEX IF NOT EXISTS idx_features_analyzed_at ON features(analyzed_at);
CREATE INDEX IF NOT EXISTS idx_features_confidence_score ON features(confidence_score);

-- Enable Row Level Security (RLS)
ALTER TABLE features ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows all operations (adjust as needed for your auth setup)
-- For production, you should create more restrictive policies based on user authentication
CREATE POLICY "Allow all operations on features" ON features
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Optional: Create a view for summary statistics
CREATE OR REPLACE VIEW features_summary AS
SELECT
    COUNT(*) as total_analyses,
    AVG(confidence_score) as avg_confidence_score,
    AVG(wpm) as avg_wpm,
    AVG(filler_count) as avg_filler_count,
    AVG(pause_ratio) as avg_pause_ratio,
    MIN(analyzed_at) as first_analysis,
    MAX(analyzed_at) as last_analysis
FROM features;

-- Grant permissions (adjust based on your Supabase setup)
GRANT ALL ON features TO authenticated;
GRANT ALL ON features TO anon;
GRANT SELECT ON features_summary TO authenticated;
GRANT SELECT ON features_summary TO anon;
