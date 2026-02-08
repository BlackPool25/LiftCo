# Gym Buddy Database Schema

## Project: LiftCo (bpfptwqysbouppknzaqk)

This document outlines the database schema created for the Gym Buddy application.

---

## Tables Overview

### 1. `gyms` - Gym Information

Stores information about gyms/locations where users work out.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Unique identifier |
| name | varchar(255) | NOT NULL | Gym name |
| latitude | decimal(10,8) | NOT NULL, -90 to 90 | GPS latitude |
| longitude | decimal(11,8) | NOT NULL, -180 to 180 | GPS longitude |
| address | text | Optional | Full address |
| opening_days | integer[] | Default [1-7] | Days open (1=Mon, 7=Sun) |
| opening_time | time | Optional | Opening hour |
| closing_time | time | Optional | Closing hour |
| phone | varchar(20) | Optional | Contact phone |
| email | varchar(255) | Optional, email format | Contact email |
| website | varchar(500) | Optional | Website URL |
| amenities | text[] | Optional | Array of amenities |
| created_at | timestamptz | Default now() | Creation timestamp |
| updated_at | timestamptz | Default now() | Last update timestamp |

**Indexes:**
- `idx_gyms_location` on (latitude, longitude)
- `idx_gyms_name` on (name)

---

### 2. `users` - User Profiles

Stores user profile information and preferences.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Unique identifier |
| name | varchar(100) | NOT NULL | User's name |
| phone_number | varchar(20) | NOT NULL, UNIQUE | Phone number |
| age | integer | Optional, 13-120 | User age |
| gender | varchar(20) | Optional | Gender identity |
| current_workout_split | workout_split_type | Optional | Current split type |
| time_working_out_months | integer | Optional, >=0 | Experience in months |
| home_gym_id | bigint | FK to gyms | Preferred gym |
| profile_photo_url | varchar(500) | Optional | Profile photo URL |
| experience_level | experience_level | Optional | Skill level |
| primary_activity | varchar(50) | Optional | Main workout type |
| bio | text | Optional | User bio/description |
| reputation_score | integer | Default 100, 0-100 | Reliability score |
| created_at | timestamptz | Default now() | Creation timestamp |
| updated_at | timestamptz | Default now() | Last update timestamp |

**Indexes:**
- `idx_users_home_gym` on (home_gym_id)
- `idx_users_phone` on (phone_number)
- `idx_users_experience` on (experience_level)
- Unique index on (phone_number)

---

### 3. `workout_sessions` - Workout Session Listings

Stores workout sessions that users can join.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Unique identifier |
| gym_id | bigint | NOT NULL, FK to gyms | Location of session |
| host_user_id | bigint | NOT NULL, FK to users | Session creator |
| title | varchar(200) | NOT NULL | Session title |
| session_type | workout_split_type | NOT NULL | Type of workout |
| description | text | Optional | Additional details |
| start_time | timestamptz | NOT NULL | Session start time |
| duration_minutes | integer | NOT NULL, 1-480 | Duration in minutes |
| max_capacity | integer | NOT NULL, 1-20, Default 4 | Max participants |
| current_count | integer | NOT NULL, 1-max | Current participants |
| status | session_status | NOT NULL, Default 'upcoming' | Session state |
| intensity_level | varchar(20) | Optional | Workout intensity |
| created_at | timestamptz | Default now() | Creation timestamp |
| updated_at | timestamptz | Default now() | Last update timestamp |

**Indexes:**
- `idx_sessions_gym` on (gym_id)
- `idx_sessions_host` on (host_user_id)
- `idx_sessions_status` on (status)
- `idx_sessions_start_time` on (start_time)
- `idx_sessions_gym_time` on (gym_id, start_time) WHERE status IN ('upcoming', 'in_progress')
- `idx_sessions_type` on (session_type)

---

### 4. `session_members` - Session Participants

Tracks which users have joined which sessions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Unique identifier |
| session_id | bigint | NOT NULL, FK to workout_sessions | Session reference |
| user_id | bigint | NOT NULL, FK to users | User reference |
| joined_at | timestamptz | Default now() | Join timestamp |
| status | varchar(20) | Default 'joined' | Membership status |

**Status Values:** 'joined', 'cancelled', 'completed', 'no_show'

**Indexes:**
- `idx_session_members_session` on (session_id)
- `idx_session_members_user` on (user_id)
- Unique index on (session_id, user_id) - prevents duplicates

---

## ENUM Types

### `workout_split_type`
- 'push', 'pull', 'legs', 'full_body', 'upper', 'lower', 'cardio', 'yoga', 'crossfit', 'other'

### `session_status`
- 'upcoming', 'in_progress', 'finished', 'cancelled'

### `experience_level`
- 'beginner', 'intermediate', 'advanced'

---

## Key Features

### Data Integrity
- **CHECK constraints** on all numeric ranges (age, capacity, duration, coordinates)
- **Email validation** regex on gym email fields
- **Phone validation** regex on user phone numbers
- **Foreign keys** with appropriate ON DELETE actions
- **Unique constraints** on phone numbers and session memberships

### Performance Optimizations
- **Indexes** on all foreign keys and frequently queried fields
- **Partial index** on gym_id + start_time for active/upcoming sessions
- **Covering indexes** for common query patterns

### Automation
- **Auto-updated timestamps** via triggers on UPDATE
- **Auto-updating current_count** when users join/leave sessions
- **Row Level Security** enabled on all tables (policies to be added)

### Relationships
- Users → Gyms (many-to-one via home_gym_id)
- Workout Sessions → Gyms (many-to-one)
- Workout Sessions → Users (many-to-one via host)
- Session Members → Workout Sessions & Users (many-to-many junction)

---

## Next Steps

1. **Add Row Level Security policies** to control data access
2. **Create storage bucket** for profile photos
3. **Set up realtime subscriptions** for live session updates
4. **Create views** for common queries (e.g., active sessions with gym info)
5. **Add trigger** to auto-update session status based on time
6. **Create function** to validate geofence location for check-ins
