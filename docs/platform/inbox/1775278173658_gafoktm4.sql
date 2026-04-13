-- migration: 20250701000000_initial_schema
-- description: Initial schema matching current Audos database state
-- author: otto
-- created: 2025-07-01T00:00:00Z
--
-- NOTE: This migration documents the existing schema.
-- It was already applied to Audos before the migration system was set up.
-- Marked as applied in _migrations_index.json.

-- Voice Profiles
CREATE TABLE voice_profiles (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    name TEXT NOT NULL,
    description TEXT,
    profile_type TEXT DEFAULT 'host',
    tone TEXT,
    vocabulary TEXT,
    phrases TEXT,
    personality TEXT,
    examples TEXT,
    user_id TEXT,
    org_id TEXT,
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP,
    usage_count INTEGER DEFAULT 0
);

-- Speakers
CREATE TABLE speakers (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    name TEXT NOT NULL,
    role TEXT DEFAULT 'guest',
    aliases TEXT,
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,
    user_id TEXT,
    org_id TEXT,
    episode_count INTEGER DEFAULT 0,
    last_appeared_at TIMESTAMP,
    notes TEXT
);

-- Guest Prep Podcast Profiles
CREATE TABLE guest_prep_podcast_profiles (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    podcast_name TEXT NOT NULL,
    podcast_description TEXT,
    target_audience TEXT,
    interview_style TEXT,
    tone TEXT,
    brand_voice TEXT,
    typical_length INTEGER,
    format_type TEXT,
    website_url TEXT,
    spotify_url TEXT,
    apple_url TEXT,
    youtube_url TEXT,
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,
    user_id TEXT,
    org_id TEXT,
    is_active BOOLEAN DEFAULT true
);

-- Guest Prep Research Sessions
CREATE TABLE guest_prep_research_sessions (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    episode_title TEXT,
    episode_number TEXT,
    scheduled_date DATE,
    guest_name TEXT NOT NULL,
    guest_title TEXT,
    guest_company TEXT,
    guest_bio TEXT,
    guest_linkedin TEXT,
    guest_twitter TEXT,
    guest_website TEXT,
    transcript TEXT,
    research_package TEXT,
    talking_points TEXT,
    questions TEXT,
    run_of_show TEXT,
    run_of_show_version INTEGER DEFAULT 1,
    podcast_profile_id TEXT REFERENCES guest_prep_podcast_profiles(id) ON DELETE SET NULL,
    speaker_id TEXT REFERENCES speakers(id) ON DELETE SET NULL,
    user_id TEXT,
    org_id TEXT,
    status TEXT DEFAULT 'draft',
    completed_at TIMESTAMP
);

-- Reels
CREATE TABLE reels (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    title TEXT NOT NULL,
    transcript_segment TEXT,
    start_time INTEGER,
    end_time INTEGER,
    episode_id TEXT,
    episode_title TEXT,
    status TEXT DEFAULT 'pending',
    scheduled_for TIMESTAMP,
    published_at TIMESTAMP,
    user_id TEXT,
    org_id TEXT,
    platforms TEXT,
    notes TEXT
);

-- Reel Captions
CREATE TABLE reel_captions (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    reel_id TEXT REFERENCES reels(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL,
    caption TEXT NOT NULL,
    hashtags TEXT,
    status TEXT DEFAULT 'draft',
    approved_at TIMESTAMP,
    user_id TEXT,
    org_id TEXT,
    feedback TEXT,
    revision_count INTEGER DEFAULT 0
);

-- Dashboard Activity
CREATE TABLE dashboard_activity (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    title TEXT NOT NULL,
    description TEXT,
    activity_type TEXT NOT NULL,
    reference_type TEXT,
    reference_id TEXT,
    user_id TEXT,
    org_id TEXT,
    metadata TEXT,
    is_read BOOLEAN DEFAULT false
);

-- rollback:
-- DROP TABLE IF EXISTS dashboard_activity;
-- DROP TABLE IF EXISTS reel_captions;
-- DROP TABLE IF EXISTS reels;
-- DROP TABLE IF EXISTS guest_prep_research_sessions;
-- DROP TABLE IF EXISTS guest_prep_podcast_profiles;
-- DROP TABLE IF EXISTS speakers;
-- DROP TABLE IF EXISTS voice_profiles;
