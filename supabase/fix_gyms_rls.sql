-- Fix for gyms RLS policy
-- Run this in your Supabase Dashboard SQL Editor

-- First, check if RLS is enabled
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname = 'gyms';

-- Disable RLS on gyms table (since gym data should be public)
ALTER TABLE gyms DISABLE ROW LEVEL SECURITY;

-- Or alternatively, create a permissive policy:
-- ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all users to read gyms" ON gyms FOR SELECT USING (true);

-- Verify the fix
SELECT * FROM gyms LIMIT 5;
