-- Fix RLS policies for workout_sessions table
-- This allows authenticated users to create sessions and manage their own sessions
-- Includes women-only session security enforcement

-- Enable RLS if not already enabled
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow users to create sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to read sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow hosts to update their sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to update sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to increment session count" ON workout_sessions;

-- Policy 1: Allow authenticated users to create sessions
-- Only female users can create women-only sessions
CREATE POLICY "Allow users to create sessions"
  ON workout_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = host_user_id
    AND (
      -- If creating women_only session, user must be female
      women_only = false 
      OR 
      (
        women_only = true 
        AND auth.uid() IN (
          SELECT id FROM users WHERE gender = 'female'
        )
      )
    )
  );

-- Policy 2: Allow users to read sessions with women-only filtering
-- Women-only sessions are only visible to female users
CREATE POLICY "Allow users to read sessions"
  ON workout_sessions
  FOR SELECT
  TO authenticated, anon
  USING (
    -- If not women_only, everyone can see it
    women_only = false 
    OR 
    -- If women_only, only show to female users
    (
      women_only = true 
      AND auth.uid() IN (
        SELECT id FROM users WHERE gender = 'female'
      )
    )
  );

-- Policy 3: Allow hosts to update their own sessions
CREATE POLICY "Allow hosts to update their sessions"
  ON workout_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = host_user_id)
  WITH CHECK (auth.uid() = host_user_id);

-- Also ensure session_members has proper policies
ALTER TABLE session_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users to join sessions" ON session_members;
DROP POLICY IF EXISTS "Allow users to read session members" ON session_members;
DROP POLICY IF EXISTS "Allow users to leave sessions" ON session_members;
DROP POLICY IF EXISTS "Allow users to update membership" ON session_members;

-- Policy 1: Allow authenticated users to join sessions
-- Only female users can join women-only sessions
CREATE POLICY "Allow users to join sessions"
  ON session_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      -- Check if session is women_only
      EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = session_id 
        AND ws.women_only = false
      )
      OR
      -- If women_only session, only females can join
      (
        EXISTS (
          SELECT 1 FROM workout_sessions ws
          WHERE ws.id = session_id 
          AND ws.women_only = true
        )
        AND auth.uid() IN (
          SELECT id FROM users WHERE gender = 'female'
        )
      )
    )
  );

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

-- Grant necessary permissions
GRANT SELECT ON users TO authenticated, anon;
