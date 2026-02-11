-- Fix session member counting with database triggers
-- This ensures current_count is always accurate based on session_members

-- First, drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_session_count_on_member_insert ON session_members;
DROP TRIGGER IF EXISTS update_session_count_on_member_update ON session_members;
DROP FUNCTION IF EXISTS update_session_member_count();

-- Create function to update session count
CREATE OR REPLACE FUNCTION update_session_member_count()
RETURNS TRIGGER AS $$
BEGIN
    -- For INSERT: increment count if status is 'joined'
    IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'joined' THEN
            UPDATE workout_sessions 
            SET current_count = current_count + 1
            WHERE id = NEW.session_id;
        END IF;
        RETURN NEW;
    
    -- For UPDATE: adjust count based on status change
    ELSIF TG_OP = 'UPDATE' THEN
        -- If changing TO joined, increment
        IF OLD.status != 'joined' AND NEW.status = 'joined' THEN
            UPDATE workout_sessions 
            SET current_count = current_count + 1
            WHERE id = NEW.session_id;
        
        -- If changing FROM joined to something else, decrement
        ELSIF OLD.status = 'joined' AND NEW.status != 'joined' THEN
            UPDATE workout_sessions 
            SET current_count = GREATEST(current_count - 1, 0)
            WHERE id = NEW.session_id;
        END IF;
        RETURN NEW;
    
    -- For DELETE: decrement if deleted member was joined
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.status = 'joined' THEN
            UPDATE workout_sessions 
            SET current_count = GREATEST(current_count - 1, 0)
            WHERE id = OLD.session_id;
        END IF;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for INSERT
CREATE TRIGGER update_session_count_on_member_insert
    AFTER INSERT ON session_members
    FOR EACH ROW
    EXECUTE FUNCTION update_session_member_count();

-- Create trigger for UPDATE
CREATE TRIGGER update_session_count_on_member_update
    AFTER UPDATE ON session_members
    FOR EACH ROW
    EXECUTE FUNCTION update_session_member_count();

-- Fix existing sessions: recalculate current_count based on actual joined members
UPDATE workout_sessions ws
SET current_count = (
    SELECT COUNT(*)
    FROM session_members sm
    WHERE sm.session_id = ws.id
    AND sm.status = 'joined'
);

-- Verify the triggers are working
SELECT 
    'Session count triggers created successfully' as status,
    tgname as trigger_name,
    tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgname IN ('update_session_count_on_member_insert', 'update_session_count_on_member_update');
