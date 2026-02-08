# Gym Buddy - CRUD API Documentation

## Overview

Complete REST API for Gym Buddy application with authentication, user profiles, gyms, workout sessions, and session membership management.

**Base URL:** `https://bpfptwqysbouppknzaqk.supabase.co/functions/v1`

---

## Table of Contents

1. [Authentication](#authentication)
2. [User Profile](#user-profile)
3. [Gyms](#gyms)
4. [Sessions](#sessions)
5. [Session Members](#session-members)
6. [Error Codes](#error-codes)
7. [Testing](#testing)

---

## Authentication

All CRUD endpoints require JWT authentication via `Authorization: Bearer <token>` header.

### Get JWT Token

Use the authentication endpoints first to obtain an access_token:

**Email Auth:**
```bash
curl -X POST "$BASE_URL/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "name": "Test User", "age": 25}'
```

**Response:**
```json
{
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "...",
    "expires_at": 1770486630
  }
}
```

Use the `access_token` in the `Authorization` header for all subsequent requests.

---

## User Profile

### A. Get My Profile

Fetch the logged-in user's profile.

**Endpoint:** `GET /users-get-me`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "user": {
    "id": 1,
    "name": "Test User",
    "email": "user@example.com",
    "phone_number": "+15551234567",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "home_gym_id": 1,
    "profile_photo_url": null,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting",
    "bio": "Love heavy lifting!",
    "reputation_score": 100,
    "created_at": "2026-02-07T16:52:21.493273+00:00",
    "updated_at": "2026-02-07T16:52:21.493273+00:00"
  }
}
```

**cURL Example:**
```bash
curl -X GET "$BASE_URL/users-get-me" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

### B. Update My Profile

Update profile details using PATCH (partial update).

**Endpoint:** `PATCH /users-update-me`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Updated Name",
  "age": 26,
  "experience_level": "advanced",
  "current_workout_split": "legs"
}
```

**Response (200):**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "id": 1,
    "name": "Updated Name",
    "age": 26,
    "experience_level": "advanced",
    "current_workout_split": "legs",
    "updated_at": "2026-02-07T17:00:00.000000+00:00"
  }
}
```

**cURL Example:**
```bash
curl -X PATCH "$BASE_URL/users-update-me" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "age": 26,
    "experience_level": "advanced"
  }'
```

**Notes:**
- Use PATCH instead of PUT to update only specific fields
- Protected fields cannot be updated: `id`, `created_at`, `reputation_score`

---

## Gyms

### A. List All Gyms

Get a list of all gyms with optional search and pagination.

**Endpoint:** `GET /gyms-list`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `search` (optional): Search by name or address
- `limit` (optional): Number of results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response (200):**
```json
{
  "gyms": [
    {
      "id": 1,
      "name": "Gold Gym",
      "latitude": 12.9716,
      "longitude": 77.5946,
      "address": "123 Main St, Bangalore",
      "opening_days": [1, 2, 3, 4, 5, 6, 7],
      "opening_time": "06:00:00",
      "closing_time": "22:00:00",
      "phone": null,
      "email": null,
      "website": null,
      "amenities": ["wifi", "parking", "shower", "lockers"],
      "created_at": "2026-02-07T16:00:00.000000+00:00"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "count": 1
  }
}
```

**cURL Examples:**
```bash
# List all gyms
curl -X GET "$BASE_URL/gyms-list" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Search gyms
curl -X GET "$BASE_URL/gyms-list?search=Gold" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Paginated results
curl -X GET "$BASE_URL/gyms-list?limit=10&offset=0" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

### B. Get Gym Details

Get detailed information about a specific gym.

**Endpoint:** `GET /gyms-get?id=<gym_id>`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `id` (required): Gym ID

**Response (200):**
```json
{
  "gym": {
    "id": 1,
    "name": "Gold Gym",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "address": "123 Main St, Bangalore",
    "opening_days": [1, 2, 3, 4, 5, 6, 7],
    "opening_time": "06:00:00",
    "closing_time": "22:00:00",
    "phone": null,
    "email": null,
    "website": null,
    "amenities": ["wifi", "parking", "shower", "lockers"],
    "created_at": "2026-02-07T16:00:00.000000+00:00"
  }
}
```

**cURL Example:**
```bash
curl -X GET "$BASE_URL/gyms-get?id=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Notes:**
- POST and DELETE for gyms are admin-only operations done via Supabase Dashboard
- Users cannot create or delete gyms through the mobile app

---

## Sessions

### A. Create Session

Create a new workout session (user becomes the host).

**Endpoint:** `POST /sessions-create`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "gym_id": 1,
  "title": "Morning Push Workout",
  "session_type": "push",
  "description": "Chest, shoulders, and triceps focus",
  "start_time": "2026-02-10T10:00:00Z",
  "duration_minutes": 60,
  "max_capacity": 4,
  "intensity_level": "high"
}
```

**Required Fields:**
- `gym_id`: Gym where session takes place
- `title`: Session title
- `session_type`: Type of workout (push, pull, legs, full_body, etc.)
- `start_time`: ISO 8601 datetime (must be in future)
- `duration_minutes`: Session duration

**Optional Fields:**
- `description`: Session details
- `max_capacity`: Max participants (default: 4)
- `intensity_level`: Workout intensity

**Response (201):**
```json
{
  "message": "Session created successfully",
  "session": {
    "id": 1,
    "gym_id": 1,
    "host_user_id": 1,
    "title": "Morning Push Workout",
    "session_type": "push",
    "description": "Chest, shoulders, and triceps focus",
    "start_time": "2026-02-10T10:00:00Z",
    "duration_minutes": 60,
    "max_capacity": 4,
    "current_count": 1,
    "status": "upcoming",
    "intensity_level": "high",
    "created_at": "2026-02-07T17:00:00.000000+00:00"
  }
}
```

**cURL Example:**
```bash
curl -X POST "$BASE_URL/sessions-create" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gym_id": 1,
    "title": "Morning Push Workout",
    "session_type": "push",
    "description": "Chest, shoulders, and triceps focus",
    "start_time": "2026-02-10T10:00:00Z",
    "duration_minutes": 60,
    "max_capacity": 4,
    "intensity_level": "high"
  }'
```

---

### B. List Sessions

Get a list of workout sessions with filtering options.

**Endpoint:** `GET /sessions-list`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `gym_id` (optional): Filter by gym
- `status` (optional): Filter by status (upcoming, in_progress, finished, cancelled)
- `session_type` (optional): Filter by type (push, pull, legs, etc.)
- `date_from` (optional): Filter sessions from date (ISO 8601)
- `date_to` (optional): Filter sessions to date (ISO 8601)
- `limit` (optional): Number of results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Default Behavior:**
- Returns only `upcoming` and `in_progress` sessions
- Sorted by start_time ascending

**Response (200):**
```json
{
  "sessions": [
    {
      "id": 1,
      "gym_id": 1,
      "host_user_id": 1,
      "title": "Morning Push Workout",
      "session_type": "push",
      "description": "Chest, shoulders, and triceps focus",
      "start_time": "2026-02-10T10:00:00Z",
      "duration_minutes": 60,
      "max_capacity": 4,
      "current_count": 2,
      "status": "upcoming",
      "intensity_level": "high",
      "host": {
        "name": "Test User"
      },
      "gym": {
        "name": "Gold Gym",
        "address": "123 Main St, Bangalore"
      },
      "members": [
        {
          "count": 2
        }
      ]
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "count": 1
  }
}
```

**cURL Examples:**
```bash
# List all upcoming sessions
curl -X GET "$BASE_URL/sessions-list" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by gym
curl -X GET "$BASE_URL/sessions-list?gym_id=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by type and gym
curl -X GET "$BASE_URL/sessions-list?gym_id=1&session_type=push" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by date range
curl -X GET "$BASE_URL/sessions-list?date_from=2026-02-10T00:00:00Z&date_to=2026-02-11T00:00:00Z" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

### C. Get Session Details

Get detailed information about a specific session including members.

**Endpoint:** `GET /sessions-get?id=<session_id>`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `id` (required): Session ID

**Response (200):**
```json
{
  "session": {
    "id": 1,
    "gym_id": 1,
    "host_user_id": 1,
    "title": "Morning Push Workout",
    "session_type": "push",
    "description": "Chest, shoulders, and triceps focus",
    "start_time": "2026-02-10T10:00:00Z",
    "duration_minutes": 60,
    "max_capacity": 4,
    "current_count": 2,
    "status": "upcoming",
    "intensity_level": "high",
    "host": {
      "id": 1,
      "name": "Test User",
      "experience_level": "intermediate"
    },
    "gym": {
      "name": "Gold Gym",
      "address": "123 Main St, Bangalore",
      "latitude": 12.9716,
      "longitude": 77.5946
    },
    "members": [
      {
        "user_id": 1,
        "status": "joined",
        "joined_at": "2026-02-07T17:00:00.000000+00:00",
        "user": {
          "name": "Test User"
        }
      },
      {
        "user_id": 2,
        "status": "joined",
        "joined_at": "2026-02-07T17:05:00.000000+00:00",
        "user": {
          "name": "Another User"
        }
      }
    ]
  }
}
```

**cURL Example:**
```bash
curl -X GET "$BASE_URL/sessions-get?id=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

### D. Cancel Session (Host Only)

Cancel a session. Only the host can cancel their own sessions.

**Endpoint:** `DELETE /sessions-delete?id=<session_id>`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `id` (required): Session ID

**Response (200):**
```json
{
  "message": "Session cancelled successfully"
}
```

**cURL Example:**
```bash
curl -X DELETE "$BASE_URL/sessions-delete?id=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Error Cases:**
- `403`: User is not the host
- `400`: Session is already finished or cancelled
- `404`: Session not found

---

## Session Members

### A. Join Session

Add the logged-in user to a session.

**Endpoint:** `POST /sessions-join`

**Headers:**
```
Authorization: Bearer <access_token>
```

**URL Structure:**
The session ID is extracted from the URL path structure. In production routing:
- Path: `/sessions/{session_id}/join`

**Validation Checks:**
1. ✅ Session exists and is joinable (not cancelled/finished)
2. ✅ User is not already a member
3. ✅ Session has capacity available
4. ✅ No time conflicts with other joined sessions

**Response (200):**
```json
{
  "message": "Successfully joined session",
  "session": {
    "id": 1,
    "title": "Morning Push Workout",
    "current_count": 3,
    "max_capacity": 4,
    "members": [...]
  }
}
```

**cURL Example:**
```bash
# Note: In production, session ID is in URL path
# For Supabase functions, pass session_id in body
curl -X POST "$BASE_URL/sessions-join" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id": 1}'
```

**Error Cases:**
- `400`: Session is full
- `400`: Session is cancelled or finished
- `409`: Already a member of this session
- `409`: Time conflict with another session

**Time Conflict Error:**
```json
{
  "error": "Time conflict",
  "message": "You have another session at this time",
  "conflicting_session_id": 2
}
```

---

### B. Leave Session

Allow a user to quit a session they joined.

**Endpoint:** `DELETE /sessions-leave`

**Headers:**
```
Authorization: Bearer <access_token>
```

**URL Structure:**
The session ID is extracted from the URL path structure. In production routing:
- Path: `/sessions/{session_id}/leave`

**Validation Checks:**
1. ✅ User is not the host (host must cancel, not leave)
2. ✅ Session is not finished or cancelled
3. ✅ User is a member of the session

**Response (200):**
```json
{
  "message": "Successfully left session",
  "session_id": 1
}
```

**cURL Example:**
```bash
# Note: In production, session ID is in URL path
# For Supabase functions, pass session_id in body
curl -X DELETE "$BASE_URL/sessions-leave" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id": 1}'
```

**Error Cases:**
- `400`: User is the host (use cancel instead)
- `400`: Session is finished or cancelled
- `400`: User is not a member

---

## Error Codes

| HTTP Status | Error | Description |
|-------------|-------|-------------|
| 400 | Invalid session ID | Session ID format is invalid |
| 400 | Session is full | Cannot join, max capacity reached |
| 400 | Time conflict | User has overlapping session |
| 400 | Cannot join a cancelled session | Session is cancelled |
| 400 | Cannot join a finished session | Session is finished |
| 400 | Host cannot leave their own session | Use cancel instead |
| 401 | Authorization header required | Missing JWT token |
| 401 | Invalid or expired session | JWT token invalid or expired |
| 403 | Only the host can cancel this session | User is not the session host |
| 404 | User profile not found | Profile doesn't exist |
| 404 | Gym not found | Gym ID doesn't exist |
| 404 | Session not found | Session ID doesn't exist |
| 409 | You are already a member of this session | Duplicate join attempt |
| 409 | You are not a member of this session | Leave attempt without joining |
| 500 | Internal server error | Server-side error |

---

## Testing

### Quick Test Script

A test script is available at `test-crud-api.sh`:

```bash
chmod +x test-crud-api.sh
./test-crud-api.sh
```

### Manual Testing with cURL

#### 1. Authenticate and Get Token

```bash
# Email signup/login
RESPONSE=$(curl -s -X POST "$BASE_URL/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "age": 25,
    "experience_level": "beginner"
  }')

echo "User created: $RESPONSE"
```

#### 2. Test User Profile

```bash
TOKEN="YOUR_ACCESS_TOKEN"

# Get profile
curl -X GET "$BASE_URL/users-get-me" \
  -H "Authorization: Bearer $TOKEN"

# Update profile
curl -X PATCH "$BASE_URL/users-update-me" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name", "age": 26}'
```

#### 3. Test Gyms

```bash
# List gyms
curl -X GET "$BASE_URL/gyms-list" \
  -H "Authorization: Bearer $TOKEN"

# Get gym details
curl -X GET "$BASE_URL/gyms-get?id=1" \
  -H "Authorization: Bearer $TOKEN"
```

#### 4. Test Sessions

```bash
# Create session
curl -X POST "$BASE_URL/sessions-create" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gym_id": 1,
    "title": "Morning Workout",
    "session_type": "push",
    "start_time": "2026-02-10T10:00:00Z",
    "duration_minutes": 60,
    "max_capacity": 4
  }'

# List sessions
curl -X GET "$BASE_URL/sessions-list?gym_id=1" \
  -H "Authorization: Bearer $TOKEN"

# Get session details
curl -X GET "$BASE_URL/sessions-get?id=1" \
  -H "Authorization: Bearer $TOKEN"

# Cancel session (host only)
curl -X DELETE "$BASE_URL/sessions-delete?id=1" \
  -H "Authorization: Bearer $TOKEN"
```

#### 5. Test Session Members

```bash
# Join session
curl -X POST "$BASE_URL/sessions-join" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id": 1}'

# Leave session
curl -X DELETE "$BASE_URL/sessions-leave" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id": 1}'
```

---

## Data Models

### Session Types

- `push` - Push workout (chest, shoulders, triceps)
- `pull` - Pull workout (back, biceps)
- `legs` - Legs workout
- `full_body` - Full body workout
- `upper` - Upper body workout
- `lower` - Lower body workout
- `cardio` - Cardio session
- `yoga` - Yoga session
- `crossfit` - CrossFit workout
- `other` - Other workout types

### Session Status

- `upcoming` - Session hasn't started yet
- `in_progress` - Session is currently happening
- `finished` - Session has ended
- `cancelled` - Session was cancelled by host

### Member Status

- `joined` - User has joined the session
- `cancelled` - User left the session
- `completed` - User attended the session
- `no_show` - User didn't show up

---

## Notes

- All timestamps are in ISO 8601 format (UTC)
- Session capacity is automatically managed when users join/leave
- Time conflicts prevent users from joining overlapping sessions
- Hosts cannot leave their own sessions; they must cancel them
- JWT tokens expire; use refresh tokens to get new access tokens
- RLS policies ensure users can only access their own data

---

## Edge Functions Summary

| Function | Method | Auth | Description |
|----------|--------|------|-------------|
| `users-get-me` | GET | JWT | Get current user profile |
| `users-update-me` | PATCH | JWT | Update user profile |
| `gyms-list` | GET | JWT | List all gyms |
| `gyms-get` | GET | JWT | Get gym details |
| `sessions-create` | POST | JWT | Create new session |
| `sessions-list` | GET | JWT | List sessions |
| `sessions-get` | GET | JWT | Get session details |
| `sessions-delete` | DELETE | JWT | Cancel session (host only) |
| `sessions-join` | POST | JWT | Join a session |
| `sessions-leave` | DELETE | JWT | Leave a session |

**Total: 10 Edge Functions**

---

## Next Steps

1. **Test all endpoints** using the provided curl commands
2. **Integrate with Flutter app** using Supabase client
3. **Add real-time subscriptions** for live session updates
4. **Implement notification system** for session reminders
5. **Add photo upload** for profile pictures and gym images
6. **Set up geolocation** for GPS verification (Phase 2)

---

## Support

For issues or questions:
- Check the error response for details
- Review the database constraints
- Verify JWT token is valid and not expired
- Ensure user profile exists before performing operations
