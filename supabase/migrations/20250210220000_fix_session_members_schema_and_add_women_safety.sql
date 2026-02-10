-- Fix session_members schema and add Women Safety Feature
-- This migration:
-- 1. Converts session_members.session_id from bigint to uuid
-- 2. Creates proper foreign key to workout_sessions
-- 3. Adds women_only column and RLS policies

-- Step 1: Backup existing data (if any)
CREATE TEMP TABLE IF NOT EXISTS session_members_backup AS 
SELECT * FROM session_members WHERE 1=0;

-- Only backup if table has data and column is still bigint
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'session_members' 
        AND column_name = 'session_id' 
        AND data_type = 'bigint'
    ) AND EXISTS (SELECT 1 FROM session_members LIMIT 1) THEN
        INSERT INTO session_members_backup SELECT * FROM session_members;
        RAISE NOTICE 'Backed up session_members data';
    END IF;
END $$;

-- Step 2: Drop foreign key constraint if exists (to avoid dependency issues)
ALTER TABLE session_members DROP CONSTRAINT IF EXISTS session_members_session_id_fkey;

-- Step 3: Check and fix session_id column type
DO $$
BEGIN
    -- Check if session_id is bigint and needs conversion
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'session_members' 
        AND column_name = 'session_id' 
        AND data_type = 'bigint'
    ) THEN
        -- Drop existing data (we can't convert bigint to uuid directly)
        TRUNCATE TABLE session_members;
        
        -- Drop and recreate column as uuid
        ALTER TABLE session_members DROP COLUMN session_id;
        ALTER TABLE session_members ADD COLUMN session_id UUID;
        
        -- Add foreign key constraint
        ALTER TABLE session_members 
        ADD CONSTRAINT session_members_session_id_fkey 
        FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Converted session_members.session_id from bigint to uuid with FK constraint';
    ELSE
        -- Column might already be uuid or not exist, ensure FK exists
        ALTER TABLE session_members 
        DROP CONSTRAINT IF EXISTS session_members_session_id_fkey;
        
        ALTER TABLE session_members 
        ADD CONSTRAINT session_members_session_id_fkey 
        FOREIGN KEY (session_id) REFERENCES workout_sessions(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Foreign key constraint added/updated';
    END IF;
END $$;

-- Step 4: Add women_only column to workout_sessions
ALTER TABLE workout_sessions ADD COLUMN IF NOT EXISTS women_only BOOLEAN DEFAULT false;

-- Step 5: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_workout_sessions_women_only ON workout_sessions(women_only);

-- Step 6: Add comment explaining the column
COMMENT ON COLUMN workout_sessions.women_only IS 'If true, only female users can see and join this session. For women safety feature.';

-- Step 7: Enable RLS
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_members ENABLE ROW LEVEL SECURITY;

-- Step 8: Drop existing policies
DROP POLICY IF EXISTS "Allow users to read sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to create sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow hosts to update their sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to update sessions" ON workout_sessions;
DROP POLICY IF EXISTS "Allow users to join sessions" ON session_members;
DROP POLICY IF EXISTS "Allow users to read session members" ON session_members;
DROP POLICY IF EXISTS "Allow users to leave sessions" ON session_members;

-- Step 9: Create SELECT policy for workout_sessions
CREATE POLICY "Allow users to read sessions"
  ON workout_sessions
  FOR SELECT
  TO authenticated, anon
  USING (
    women_only = false 
    OR 
    (
      women_only = true 
      AND auth.uid() IN (
        SELECT id FROM users WHERE gender = 'female'
      )
    )
  );

-- Step 10: Create INSERT policy for workout_sessions
CREATE POLICY "Allow users to create sessions"
  ON workout_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = host_user_id
    AND (
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

-- Step 11: Create UPDATE policy for workout_sessions
CREATE POLICY "Allow hosts to update their sessions"
  ON workout_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = host_user_id)
  WITH CHECK (auth.uid() = host_user_id);

-- Step 12: Create INSERT policy for session_members
CREATE POLICY "Allow users to join sessions"
  ON session_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = session_id 
        AND ws.women_only = false
      )
      OR
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

-- Step 13: Create SELECT policy for session_members
CREATE POLICY "Allow users to read session members"
  ON session_members
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Step 14: Create UPDATE policy for session_members
CREATE POLICY "Allow users to leave sessions"
  ON session_members
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Step 15: Grant permissions
GRANT SELECT ON users TO authenticated, anon;

-- Verification queries
SELECT 
  'Schema updated successfully' as status,
  column_name, 
  data_type
FROM information_schema.columns 
WHERE table_name = 'session_members' 
AND column_name = 'session_id';

SELECT 
  'women_only column added' as status,
  column_name, 
  data_type
FROM information_schema.columns 
WHERE table_name = 'workout_sessions' 
AND column_name = 'women_only';

SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name = 'session_members';
