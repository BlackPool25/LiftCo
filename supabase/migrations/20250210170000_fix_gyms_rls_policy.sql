-- Enable RLS on gyms table (if not already enabled)
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow authenticated users to read gyms" ON gyms;
DROP POLICY IF EXISTS "Allow anonymous users to read gyms" ON gyms;
DROP POLICY IF EXISTS "Allow all users to read gyms" ON gyms;

-- Create policy to allow ALL users (authenticated and anonymous) to read gyms
CREATE POLICY "Allow all users to read gyms"
  ON gyms
  FOR SELECT
  USING (true);

-- Keep existing policies for insert/update/delete if they exist
-- Only service_role should be able to modify gyms
