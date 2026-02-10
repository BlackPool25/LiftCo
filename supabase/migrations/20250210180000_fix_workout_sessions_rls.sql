-- Fix RLS policies for workout_sessions table
-- This allows authenticated users to create sessions and manage their own sessions

-- Enable RLS if not already enabled
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow users to create sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to read sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow hosts to update their sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to join sessions" ON workout_sessions;

-- Policy 1: Allow authenticated users to create sessions
CREATE POLICY "Allow users to create sessions"
  ON workout_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = host_user_id);

-- Policy 2: Allow all users to read sessions
CREATE POLICY "Allow users to read sessions"
  ON workout_sessions
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Policy 3: Allow hosts to update their own sessions
CREATE POLICY "Allow hosts to update their sessions"
  ON workout_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = host_user_id)
  WITH CHECK (auth.uid() = host_user_id);

-- Policy 4: Allow users to update session count when joining (increment)
CREATE POLICY "Allow users to increment session count"
  ON workout_sessions
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Also ensure session_members has proper policies
ALTER TABLE session_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users to join sessions" ON session_members;
DROP POLICY IF EXISTS "Allow users to read session members" ON session_members;
DROP POLICY IF EXISTS "Allow users to leave sessions" ON session_members;

-- Policy 1: Allow authenticated users to join sessions
CREATE POLICY "Allow users to join sessions"
  ON session_members
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy 2: Allow all users to read session members
CREATE POLICY "Allow users to read session members"
  ON session_members
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Policy 3: Allow users to update their own membership (leave/cancel)
CREATE POLICY "Allow users to leave sessions"
  ON session_members
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
