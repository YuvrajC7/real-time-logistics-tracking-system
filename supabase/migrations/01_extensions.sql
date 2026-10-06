-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- pg_cron for scheduled materialized view refresh (enable in Supabase dashboard if needed)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
