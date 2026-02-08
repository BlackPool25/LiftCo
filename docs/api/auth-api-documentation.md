# Gym Buddy Authentication API Documentation

## Overview

Phone number and Email-based OTP authentication system for Gym Buddy app using Supabase Auth.

**Authentication Methods:**
- **Phone OTP** - SMS-based (requires SMS provider)
- **Email OTP** - Email-based (requires SMTP provider) ← **RECOMMENDED for cost savings**

**Base URL:** `https://bpfptwqysbouppknzaqk.supabase.co/functions/v1`

**Project ID:** `bpfptwqysbouppknzaqk`

---

## Authentication Flow

### 1. Request OTP

Send an OTP to the user's phone number. Works for both signup and login.

**Endpoint:** `POST /auth-request-otp`

**Request Body:**
```json
{
  "phone": "+15551234567"
}
```

**Success Response (200):**
```json
{
  "message": "OTP sent successfully",
  "isNewUser": true,
  "phone": "+15551234567"
}
```

**Error Response (400):**
```json
{
  "error": "Invalid phone number format. Use E.164 format (e.g., +1234567890)"
}
```

### 2. Verify OTP

Verify the OTP code and receive authentication session.

**Endpoint:** `POST /auth-verify-otp`

**Request Body:**
```json
{
  "phone": "+15551234567",
  "otp": "123456"
}
```

**Success Response (200) - New User:**
```json
{
  "message": "Authentication successful",
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "-yeACfBRfzz-9bCJca2Yog...",
    "expires_at": 1770486630
  },
  "user": {
    "id": "bc5ef75b-320d-4912-85a5-a48f96f76d79",
    "phone": "+15551234567"
  },
  "isProfileComplete": false,
  "profile": null
}
```

**Success Response (200) - Existing User:**
```json
{
  "message": "Authentication successful",
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "-yeACfBRfzz-9bCJca2Yog...",
    "expires_at": 1770486630
  },
  "user": {
    "id": "bc5ef75b-320d-4912-85a5-a48f96f76d79",
    "phone": "+15551234567"
  },
  "isProfileComplete": true,
  "profile": {
    "id": 1,
    "name": "Test User",
    "phone_number": "+15551234567",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "home_gym_id": null,
    "profile_photo_url": null,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting",
    "bio": null,
    "reputation_score": 100,
    "created_at": "2026-02-07T16:52:21.493273+00:00",
    "updated_at": "2026-02-07T16:52:21.493273+00:00"
  }
}
```

### 3. Complete Profile (New Users Only)

After verifying OTP for a new user, complete their profile with additional details.

**Endpoint:** `POST /auth-complete-profile`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "John Doe",
  "age": 25,
  "gender": "male",
  "current_workout_split": "push",
  "time_working_out_months": 12,
  "experience_level": "intermediate",
  "primary_activity": "weightlifting",
  "bio": "Looking for gym buddies!",
  "home_gym_id": 1
}
```

**Success Response (201):**
```json
{
  "message": "Profile created successfully",
  "profile": {
    "id": 1,
    "name": "John Doe",
    "phone_number": "+15551234567",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "home_gym_id": 1,
    "profile_photo_url": null,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting",
    "bio": "Looking for gym buddies!",
    "reputation_score": 100,
    "created_at": "2026-02-07T16:52:21.493273+00:00",
    "updated_at": "2026-02-07T16:52:21.493273+00:00"
  }
}
```

**Error Response (409) - Profile Already Exists:**
```json
{
  "error": "Profile already exists"
}
```

---

## Testing with cURL

### Test 1: Request OTP
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-request-otp" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+15551234567"
  }'
```

### Test 2: Verify OTP
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-verify-otp" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+15551234567",
    "otp": "123456"
  }'
```

### Test 3: Complete Profile
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-complete-profile" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{
    "name": "John Doe",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting"
  }'
```

---

## Email Authentication (Alternative - FREE)

Email-based OTP authentication using Supabase's built-in email service. **No SMS costs!**

### Email Authentication Flow

Same 3-step process as phone authentication:

### 1. Request Email OTP

Send an OTP to the user's email address.

**Endpoint:** `POST /auth-email-request-otp`

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Success Response (200):**
```json
{
  "message": "OTP sent to email successfully",
  "isNewUser": true,
  "email": "user@example.com"
}
```

**Error Response (400):**
```json
{
  "error": "Invalid email format"
}
```

### 2. Verify Email OTP

Verify the OTP code from the email.

**Endpoint:** `POST /auth-email-verify-otp`

**Request Body:**
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

**Success Response (200):**
```json
{
  "message": "Authentication successful",
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "-yeACfBRfzz-9bCJca2Yog...",
    "expires_at": 1770486630
  },
  "user": {
    "id": "bb49a647-4874-4ddb-bba9-afdffece2580",
    "email": "user@example.com"
  },
  "isProfileComplete": false,
  "profile": null
}
```

### 3. Complete Email Profile

After verifying OTP for a new user, complete their profile.

**Endpoint:** `POST /auth-email-complete-profile`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Jane Doe",
  "phone_number": "+15551234567",
  "age": 28,
  "gender": "female",
  "current_workout_split": "legs",
  "time_working_out_months": 18,
  "experience_level": "advanced",
  "primary_activity": "crossfit",
  "bio": "Love heavy lifting!",
  "home_gym_id": 1
}
```

**Success Response (201):**
```json
{
  "message": "Profile created successfully",
  "profile": {
    "id": 2,
    "name": "Jane Doe",
    "email": "user@example.com",
    "phone_number": "+15551234567",
    "age": 28,
    "gender": "female",
    "current_workout_split": "legs",
    "time_working_out_months": 18,
    "experience_level": "advanced",
    "primary_activity": "crossfit",
    "bio": "Love heavy lifting!",
    "reputation_score": 100
  }
}
```

---

## Testing with cURL - Email Auth

### Test 1: Request Email OTP
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-request-otp" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

### Test 2: Verify Email OTP
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-verify-otp" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "otp": "123456"
  }'
```

### Test 3: Complete Profile (Email)
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-complete-profile" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE" \
  -d '{
    "name": "Jane Doe",
    "age": 28,
    "gender": "female",
    "current_workout_split": "legs",
    "experience_level": "advanced"
  }'
```

### Test 4: Email Signup (Development Only)
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "age": 28,
    "gender": "female",
    "experience_level": "advanced"
  }'
```

---

## Testing with Postman

### Collection Setup

1. Create a new Collection called "Gym Buddy Auth"
2. Set base URL: `https://bpfptwqysbouppknzaqk.supabase.co/functions/v1`

### Request 1: Send OTP (Phone)

- **Method:** POST
- **URL:** `{{base_url}}/auth-request-otp`
- **Headers:**
  - `Content-Type: application/json`
- **Body (raw JSON):**
```json
{
  "phone": "+15551234567"
}
```

### Request 2: Verify OTP

- **Method:** POST
- **URL:** `{{base_url}}/auth-verify-otp`
- **Headers:**
  - `Content-Type: application/json`
- **Body (raw JSON):**
```json
{
  "phone": "+15551234567",
  "otp": "123456"
}
```
- **Test Script:** Save access_token to environment variable
```javascript
const response = pm.response.json();
if (response.session && response.session.access_token) {
    pm.environment.set("access_token", response.session.access_token);
    pm.environment.set("refresh_token", response.session.refresh_token);
}
```

### Request 3: Complete Profile

- **Method:** POST
- **URL:** `{{base_url}}/auth-complete-profile`
- **Headers:**
  - `Content-Type: application/json`
  - `Authorization: Bearer {{access_token}}`
- **Body (raw JSON):**
```json
{
  "name": "John Doe",
  "age": 25,
  "gender": "male",
  "current_workout_split": "push",
  "time_working_out_months": 12,
  "experience_level": "intermediate",
  "primary_activity": "weightlifting",
  "bio": "Looking for gym buddies!"
}
```

---

## Development/Test Mode

For testing without configuring SMS provider:

### Test Signup Endpoint (Development Only)

**⚠️ WARNING:** This endpoint bypasses OTP verification. Use only in development/testing.

**Endpoint:** `POST /auth-test-signup`

**Request Body:**
```json
{
  "phone": "+15551234567",
  "name": "Test User",
  "age": 25,
  "gender": "male",
  "current_workout_split": "push",
  "time_working_out_months": 12,
  "experience_level": "intermediate",
  "primary_activity": "weightlifting",
  "bio": "Test user bio"
}
```

**cURL Test:**
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+15551234567",
    "name": "Test User",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting"
  }'
```

---

## Development/Test Mode

For testing without configuring SMS/Email providers:

### Test Signup Endpoints (Development Only)

**⚠️ WARNING:** These endpoints bypass OTP verification. Use only in development/testing.

#### Phone Test Signup

**Endpoint:** `POST /auth-test-signup`

**Request Body:**
```json
{
  "phone": "+15551234567",
  "name": "Test User",
  "age": 25,
  "gender": "male",
  "current_workout_split": "push",
  "time_working_out_months": 12,
  "experience_level": "intermediate",
  "primary_activity": "weightlifting",
  "bio": "Test user bio"
}
```

**cURL Test:**
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+15551234567",
    "name": "Test User",
    "age": 25,
    "gender": "male",
    "current_workout_split": "push",
    "time_working_out_months": 12,
    "experience_level": "intermediate",
    "primary_activity": "weightlifting"
  }'
```

#### Email Test Signup

**Endpoint:** `POST /auth-email-test-signup`

**Request Body:**
```json
{
  "email": "test@example.com",
  "name": "Test User",
  "phone_number": "+15559876543",
  "age": 28,
  "gender": "female",
  "current_workout_split": "legs",
  "time_working_out_months": 18,
  "experience_level": "advanced",
  "primary_activity": "crossfit",
  "bio": "Love heavy lifting!"
}
```

**cURL Test:**
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "phone_number": "+15559876543",
    "age": 28,
    "gender": "female",
    "current_workout_split": "legs",
    "time_working_out_months": 18,
    "experience_level": "advanced",
    "primary_activity": "crossfit",
    "bio": "Love heavy lifting!"
  }'
```

---

## Provider Configuration (Production)

### SMS Provider (Phone OTP)

To enable real SMS OTP in production:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project: **LiftCo**
3. Go to **Authentication** → **Providers**
4. Find **Phone** provider
5. Enable it
6. Configure one of the following:
   - **Twilio**: Account SID, Auth Token, From Number
   - **Vonage**: API Key, API Secret, From Number
   - **MessageBird**: Access Key, From Number
   - **Textlocal**: API Key, From Number

### Test Numbers (Development)

Configure test phone numbers in Supabase Dashboard to receive OTPs without using real SMS:
- `+15551234567` → OTP: `123456`
- `+15559876543` → OTP: `654321`

### Email Provider (Email OTP)

To enable real email OTP in production:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project: **LiftCo**
3. Go to **Authentication** → **Providers**
4. Find **Email** provider
5. Enable it
6. Configure SMTP settings:
   - **SMTP Host**: smtp.gmail.com (or your provider)
   - **SMTP Port**: 587 (TLS) or 465 (SSL)
   - **SMTP Username**: Your email address
   - **SMTP Password**: Your app password (not regular password)

**Free SMTP Options:**
- **Gmail**: 500 emails/day (requires app password with 2FA)
- **SendGrid**: 100 emails/day free tier
- **Mailgun**: 5,000 emails/month free tier
- **AWS SES**: 62,000 emails/month free tier (first year)

### Test Emails (Development)

Configure test email addresses in Supabase Dashboard:
- `test@example.com` → OTP: `123456`
- `user@example.com` → OTP: `654321`

---

## Data Schema

### Users Table Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | User's full name |
| `phone_number` | string | Conditional | E.164 format phone number (required for phone auth) |
| `email` | string | Conditional | Valid email address (required for email auth) |
| `age` | integer | No | User age (13-120) |
| `gender` | string | No | Gender identity |
| `current_workout_split` | enum | No | Current training split |
| `time_working_out_months` | integer | No | Experience in months |
| `home_gym_id` | integer | No | Reference to gyms table |
| `profile_photo_url` | string | No | URL to profile photo |
| `experience_level` | enum | No | beginner/intermediate/advanced |
| `primary_activity` | string | No | Main workout type |
| `bio` | string | No | User bio/description |
| `reputation_score` | integer | No | 0-100 reliability score |

### Workout Split Options

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

---

## Security Features

1. **Row Level Security (RLS)** enabled on all tables
2. Users can only view/update their own profile
3. Service role bypass for Edge Functions
4. Phone number format validation (E.164)
5. Email format validation (standard email regex)
6. OTP expires in 15 minutes (configurable in Supabase)
7. Sessions include access and refresh tokens
8. Unique constraints on phone_number and email fields

---

## Error Codes

| HTTP Status | Error | Description |
|-------------|-------|-------------|
| 400 | Invalid phone number format | Phone must be E.164 format (+1234567890) |
| 400 | Invalid email format | Email must be valid format (user@example.com) |
| 400 | Phone/Email and OTP are required | Missing required fields |
| 401 | Invalid or expired OTP | OTP verification failed |
| 401 | Invalid or expired session | JWT token invalid |
| 409 | Profile already exists | User already has a profile |
| 409 | Email already exists | Email is already registered |
| 409 | Phone number already exists | Phone is already registered |
| 500 | Internal server error | Server-side error |

---

## Notes

- OTP expires in 15 minutes (default Supabase setting)
- Phone numbers must be in E.164 format (e.g., +15551234567)
- Email authentication is **FREE** using Supabase's built-in email service
- SMS authentication requires paid provider (Twilio, Vonage, etc.)
- Test endpoints (`auth-test-signup`, `auth-email-test-signup`) should be removed in production
- Profile photos should be uploaded to Supabase Storage after profile creation
- Use the `access_token` from the session for authenticated requests
- Refresh tokens can be used to get new access tokens when they expire
- Users can have both phone and email linked to their profile
