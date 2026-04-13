-- Throughline Database Schema
-- ============================
-- This is the source of truth for the database schema.
-- Update this file, then run: atlas migrate diff migration_name --env local
--
-- Note: The Audos platform auto-adds 'id' (UUID PK) and 'created_at' (TIMESTAMP)
-- to all tables. Include them here for local development parity.
--
-- Last updated: July 2025

-- ============================================
-- Core Tables
-- ============================================

-- Voice Profiles: Voice fingerprints for podcast hosts and brands
CREATE TABLE IF NOT EXISTS voice_profiles (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Core fields
    name TEXT NOT NULL,
    description TEXT,
    profile_type TEXT DEFAULT 'host', -- 'host', 'brand', 'guest'

    -- Voice characteristics
    tone TEXT,
    vocabulary TEXT,
    phrases TEXT,
    personality TEXT,
    examples TEXT,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP,
    usage_count INTEGER DEFAULT 0
);

-- Speakers: Registry for transcript parsing
CREATE TABLE IF NOT EXISTS speakers (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Core fields
    name TEXT NOT NULL,
    role TEXT DEFAULT 'guest', -- 'host', 'co-host', 'guest'
    aliases TEXT, -- JSON array of name variations

    -- Profile link
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    episode_count INTEGER DEFAULT 0,
    last_appeared_at TIMESTAMP,
    notes TEXT
);

-- Podcast Profiles: Show-level configuration
CREATE TABLE IF NOT EXISTS guest_prep_podcast_profiles (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Basic info
    podcast_name TEXT NOT NULL,
    podcast_description TEXT,
    target_audience TEXT,

    -- Style and tone
    interview_style TEXT,
    tone TEXT,
    brand_voice TEXT,

    -- Format
    typical_length INTEGER, -- minutes
    format_type TEXT, -- 'interview', 'solo', 'panel', 'narrative'

    -- Links
    website_url TEXT,
    spotify_url TEXT,
    apple_url TEXT,
    youtube_url TEXT,

    -- Voice profile
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    is_active BOOLEAN DEFAULT true
);

-- Research Sessions: Per-episode guest research
CREATE TABLE IF NOT EXISTS guest_prep_research_sessions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Episode info
    episode_title TEXT,
    episode_number TEXT,
    scheduled_date DATE,

    -- Guest info
    guest_name TEXT NOT NULL,
    guest_title TEXT,
    guest_company TEXT,
    guest_bio TEXT,
    guest_linkedin TEXT,
    guest_twitter TEXT,
    guest_website TEXT,

    -- Research content
    transcript TEXT,
    research_package TEXT, -- Generated JSON
    talking_points TEXT,
    questions TEXT,

    -- Run of Show
    run_of_show TEXT,
    run_of_show_version INTEGER DEFAULT 1,

    -- Links
    podcast_profile_id TEXT REFERENCES guest_prep_podcast_profiles(id) ON DELETE SET NULL,
    speaker_id TEXT REFERENCES speakers(id) ON DELETE SET NULL,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Status
    status TEXT DEFAULT 'draft', -- 'draft', 'ready', 'recorded', 'published'
    completed_at TIMESTAMP
);

-- Run of Show Versions: Version history
CREATE TABLE IF NOT EXISTS guest_prep_ros_versions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    session_id TEXT REFERENCES guest_prep_research_sessions(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    change_summary TEXT,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT
);

-- ============================================
-- Studio Tables (Content Generation)
-- ============================================

-- Reels: Social media content pieces
CREATE TABLE IF NOT EXISTS reels (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Content
    title TEXT NOT NULL,
    transcript_segment TEXT,
    start_time INTEGER, -- seconds
    end_time INTEGER,

    -- Source
    episode_id TEXT,
    episode_title TEXT,

    -- Status
    status TEXT DEFAULT 'pending', -- 'pending', 'captioned', 'scheduled', 'published'
    scheduled_for TIMESTAMP,
    published_at TIMESTAMP,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    platforms TEXT, -- JSON array of target platforms
    notes TEXT
);

-- Reel Captions: Generated captions per platform
CREATE TABLE IF NOT EXISTS reel_captions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    reel_id TEXT REFERENCES reels(id) ON DELETE CASCADE,

    -- Platform targeting
    platform TEXT NOT NULL, -- 'instagram', 'tiktok', 'youtube', 'linkedin', 'twitter'

    -- Voice
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,

    -- Content
    caption TEXT NOT NULL,
    hashtags TEXT,

    -- Status
    status TEXT DEFAULT 'draft', -- 'draft', 'approved', 'published'
    approved_at TIMESTAMP,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Feedback
    feedback TEXT,
    revision_count INTEGER DEFAULT 0
);

-- Studio Episodes: Episode drops for content gen
CREATE TABLE IF NOT EXISTS studio_episodes (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    title TEXT NOT NULL,
    description TEXT,
    transcript TEXT,

    -- Source
    audio_url TEXT,
    video_url TEXT,
    duration INTEGER, -- seconds

    -- Processing
    status TEXT DEFAULT 'pending', -- 'pending', 'processing', 'ready', 'published'
    processed_at TIMESTAMP,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Counts
    reels_count INTEGER DEFAULT 0,
    captions_generated INTEGER DEFAULT 0
);

-- Voice Refinements: Training data for voice models
CREATE TABLE IF NOT EXISTS voice_refinements (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE CASCADE,

    -- Refinement content
    input_text TEXT NOT NULL, -- Original/generated text
    feedback TEXT NOT NULL, -- User feedback
    refined_text TEXT, -- Improved version

    -- Context
    context_type TEXT, -- 'caption', 'email', 'script', etc.
    platform TEXT,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    applied BOOLEAN DEFAULT false,
    applied_at TIMESTAMP
);

-- ============================================
-- Activity and Tracking Tables
-- ============================================

-- Dashboard Activity: Activity feed
CREATE TABLE IF NOT EXISTS dashboard_activity (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    title TEXT NOT NULL,
    description TEXT,
    activity_type TEXT NOT NULL, -- 'research', 'caption', 'episode', 'voice', etc.

    -- Reference
    reference_type TEXT, -- 'session', 'reel', 'episode', etc.
    reference_id TEXT,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT,

    -- Metadata
    metadata TEXT, -- JSON for additional data
    is_read BOOLEAN DEFAULT false
);

-- Studio Time Tracking: Automation ROI
CREATE TABLE IF NOT EXISTS studio_time_tracking (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    task_type TEXT NOT NULL, -- 'caption', 'research', 'transcription'
    time_saved_minutes INTEGER NOT NULL,

    -- Reference
    reference_type TEXT,
    reference_id TEXT,

    -- Multi-tenancy
    user_id TEXT,
    org_id TEXT
);

-- ============================================
-- Indexes
-- ============================================

-- Performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_speakers_voice_profile ON speakers(voice_profile_id);
CREATE INDEX IF NOT EXISTS idx_research_sessions_podcast ON guest_prep_research_sessions(podcast_profile_id);
CREATE INDEX IF NOT EXISTS idx_research_sessions_status ON guest_prep_research_sessions(status);
CREATE INDEX IF NOT EXISTS idx_reels_status ON reels(status);
CREATE INDEX IF NOT EXISTS idx_reel_captions_reel ON reel_captions(reel_id);
CREATE INDEX IF NOT EXISTS idx_reel_captions_platform ON reel_captions(platform);
CREATE INDEX IF NOT EXISTS idx_voice_refinements_profile ON voice_refinements(voice_profile_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_activity_type ON dashboard_activity(activity_type);

-- Multi-tenancy indexes
CREATE INDEX IF NOT EXISTS idx_voice_profiles_user ON voice_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_profiles_org ON voice_profiles(org_id);
CREATE INDEX IF NOT EXISTS idx_speakers_user ON speakers(user_id);
CREATE INDEX IF NOT EXISTS idx_speakers_org ON speakers(org_id);
CREATE INDEX IF NOT EXISTS idx_reels_user ON reels(user_id);
CREATE INDEX IF NOT EXISTS idx_reels_org ON reels(org_id);
