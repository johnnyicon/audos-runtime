-- migration: 20250701000002_example_create_table
-- description: EXAMPLE - Create a new table
-- author: your_name
-- created: 2025-07-01T00:00:02Z
--
-- This is an EXAMPLE migration showing the format Otto expects.
-- Delete this file or modify it for your actual needs.
--
-- NOTE: The Audos platform auto-adds 'id' and 'created_at' columns,
-- but include them here for local development parity.

CREATE TABLE example_feature (
    -- Auto-added by Audos (include for local parity)
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Your columns
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,

    -- Multi-tenancy (recommended)
    user_id TEXT,
    org_id TEXT,

    -- Foreign key example
    voice_profile_id TEXT REFERENCES voice_profiles(id) ON DELETE SET NULL
);

-- Indexes
CREATE INDEX idx_example_feature_user ON example_feature(user_id);
CREATE INDEX idx_example_feature_org ON example_feature(org_id);

-- rollback:
-- DROP TABLE IF EXISTS example_feature;
