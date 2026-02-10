-- Women Safety Feature Migration
-- Adds women_only column to workout_sessions and updates RLS policies

-- Add women_only column to workout_sessions
ALTER TABLE workout_sessions ADD COLUMN IF NOT EXISTS women_only BOOLEAN DEFAULT false;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_workout_sessions_women_only ON workout_sessions(women_only);

-- Add comment explaining the column
COMMENT ON COLUMN workout_sessions.women_only IS 'If true, only female users can see and join this session. For women safety feature.';

-- Update existing RLS policies to respect women_only flag

-- Drop existing select policy to recreate with women_only logic
DROP POLICY IF EXISTS "Allow users to read sessions" ON workout_sessions;

-- Create new select policy that filters women_only sessions
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

-- Policy to ensure only females can create women_only sessions
DROP POLICY IF EXISTS "Allow users to create sessions" ON workout_sessions;

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

-- Ensure only females can join women_only sessions via session_members
DROP POLICY IF EXISTS "Allow users to join sessions" ON session_members;

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

-- Verify the migration
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'workout_sessions' 
AND column_name = 'women_only';
