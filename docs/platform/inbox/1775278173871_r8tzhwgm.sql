-- migration: 20250701000001_example_add_column
-- description: EXAMPLE - Add a new column to an existing table
-- author: your_name
-- created: 2025-07-01T00:00:01Z
--
-- This is an EXAMPLE migration showing the format Otto expects.
-- Delete this file or modify it for your actual needs.

-- Add a new column
ALTER TABLE voice_profiles ADD COLUMN custom_field TEXT;

-- Add an index for performance (optional)
CREATE INDEX idx_voice_profiles_custom_field ON voice_profiles(custom_field);

-- rollback:
-- DROP INDEX IF EXISTS idx_voice_profiles_custom_field;
-- ALTER TABLE voice_profiles DROP COLUMN custom_field;
