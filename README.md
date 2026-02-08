# Gym Buddy App

A session-based gym buddy coordination app with passive GPS verification, built with Flutter and Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-181818?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)](https://firebase.google.com)

## 📱 Overview

Gym Buddy helps fitness enthusiasts find workout partners at their specific gym through session-based matching. Unlike dating apps, it focuses purely on fitness accountability and safety.

### Key Features

- **Session-Based Matching** - Join specific workout sessions instead of permanent buddy matching
- **Anti-Dating Design** - Stats-first profiles, no swiping, contextual chat only
- **Dual Authentication** - Email (FREE) or Phone OTP
- **Real-time Notifications** - FCM-powered push notifications when users join sessions
- **Smart Validation** - Time conflict detection, capacity management
- **GPS Verification** - Passive location verification (Phase 2)

---

## 🏗️ Architecture

### Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | Flutter | Cross-platform mobile app (iOS/Android) |
| **Backend** | Supabase | Database, Auth, Edge Functions, Realtime |
| **Database** | PostgreSQL | Relational data with geospatial support |
| **Notifications** | Firebase Cloud Messaging | Push notifications |
| **Storage** | Supabase Storage | Profile photos, gym images |

### System Architecture

```
┌─────────────────┐
│   Flutter App   │
└────────┬────────┘
         │
         │ HTTPS / WebSocket
         ▼
┌─────────────────────────────┐
│         Supabase            │
│  ┌─────────────────────┐    │
│  │   Edge Functions    │    │
│  │  (18 Functions)     │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   PostgreSQL DB     │    │
│  │  (5 Tables + RLS)   │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   Auth (Email/OTP)  │    │
│  └─────────────────────┘    │
└────────┬────────────────────┘
         │
         │ FCM API
         ▼
┌─────────────────────────────┐
│   Firebase Cloud Messaging  │
│      (Push Notifications)   │
└─────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Node.js](https://nodejs.org/) (for local development)
- Firebase project with Cloud Messaging enabled

### 1. Clone and Setup

```bash
# Clone repository
git clone <your-repo-url>
cd gym-buddy

# Install Flutter dependencies
flutter pub get

# Setup environment variables
cp .env.example .env
```

### 2. Environment Variables

Create a `.env` file with the following:

```bash
# Supabase Configuration
SUPABASE_URL=https://bpfptwqysbouppknzaqk.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Firebase Configuration (for FCM)
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}

# Optional: For local development
SUPABASE_LOCAL=false
```

**Base URL for API Calls:**
```
https://bpfptwqysbouppknzaqk.supabase.co/functions/v1
```

**Important:** All Edge Functions must be called via `/functions/v1/` path:
- ✅ Correct: `https://<project>.supabase.co/functions/v1/devices-register`
- ❌ Wrong: `https://<project>.supabase.co/devices-register`

**Get Firebase Service Account JSON:**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Project Settings → Service Accounts
4. Click "Generate new private key"
5. Download JSON and paste contents as `FIREBASE_SERVICE_ACCOUNT_JSON`

### 3. Configure Supabase Secrets

```bash
# Set environment variables in Supabase
supabase secrets set FIREBASE_PROJECT_ID=your_project_id
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

### 4. Run the App

```bash
# Run on connected device
flutter run

# Or specify device
flutter run -d <device_id>
```

---

## 📊 Database Schema

### Tables Overview

```sql
users                    # User profiles
├── id (PK)
├── name
├── email
├── phone_number
├── age, gender
├── current_workout_split
├── experience_level
└── reputation_score

gyms                     # Gym locations
├── id (PK)
├── name
├── latitude, longitude
├── address
├── opening_days, opening_time, closing_time
└── amenities[]

workout_sessions         # Workout sessions
├── id (PK)
├── gym_id (FK)
├── host_user_id (FK)
├── title, description
├── session_type
├── start_time, duration_minutes
├── max_capacity, current_count
└── status

session_members          # Session participants
├── id (PK)
├── session_id (FK)
├── user_id (FK)
├── status
└── joined_at

user_devices             # FCM tokens for notifications
├── id (PK)
├── user_id (FK)
├── fcm_token
├── device_type, device_name
├── is_active
└── last_seen_at
```

See [docs/database/database-schema.md](docs/database/database-schema.md) for full details.

---

## 🔌 API Endpoints

### Base URL
```
https://bpfptwqysbouppknzaqk.supabase.co/functions/v1
```

### Authentication (8 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth-email-request-otp` | POST | Request email OTP |
| `/auth-email-verify-otp` | POST | Verify email OTP |
| `/auth-email-complete-profile` | POST | Complete profile (new users) |
| `/auth-email-test-signup` | POST | Test signup (dev only) |
| `/auth-request-otp` | POST | Request phone OTP |
| `/auth-verify-otp` | POST | Verify phone OTP |
| `/auth-complete-profile` | POST | Complete phone profile |
| `/auth-test-signup` | POST | Test phone signup |

### User Profile (2 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/users-get-me` | GET | Get current user profile |
| `/users-update-me` | PATCH | Update user profile |

### Gyms (2 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/gyms-list` | GET | List all gyms |
| `/gyms-get?id={id}` | GET | Get gym details |

### Sessions (4 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sessions-create` | POST | Create new session |
| `/sessions-list` | GET | List sessions (with filters) |
| `/sessions-get?id={id}` | GET | Get session details |
| `/sessions-delete?id={id}` | DELETE | Cancel session (host only) |

### Session Members (2 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sessions-join` | POST | Join a session |
| `/sessions-leave` | DELETE | Leave a session |

### Device Management (2 Functions)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/devices-register` | POST | Register FCM token |
| `/devices-remove` | DELETE | Remove FCM token |

### Notifications (1 Function)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/notifications-send` | POST | Send FCM notifications (internal) |

**Total: 21 Edge Functions**

See [docs/api/](docs/api/) for detailed API documentation.

---

## 🔔 Notification System

### Overview

When a user joins a session, all existing members receive a push notification:

```
Title: Squad Update! 💪
Body: {user_name} joined your {session_title} session on {date_time}!
```

### How It Works

1. **User joins session** → `/sessions-join` endpoint
2. **System validates** capacity, time conflicts, etc.
3. **Notification triggered** → Sends FCM to existing members
4. **FCM tokens fetched** from `user_devices` table
5. **Invalid tokens auto-deleted** (user uninstalled app)

### Device Registration

Register device when user logs in:

```dart
// Flutter example
final fcmToken = await FirebaseMessaging.instance.getToken();

await supabase.functions.invoke(
  'devices-register',
  body: {
    'fcm_token': fcmToken,
    'device_type': Platform.isAndroid ? 'Android' : 'iOS',
    'device_name': 'iPhone 13', // Optional
  },
);
```

### Security

- **RLS Policies**: Users can only access their own device tokens
- **Auto-cleanup**: Invalid FCM tokens are automatically deleted
- **Service Role**: Only backend can send notifications to other users

---

## 🔐 Security

### Row Level Security (RLS)

All tables have RLS enabled with the following policies:

**users table:**
- Users can only view/update their own profile
- Service role has full access

**user_devices table:**
- Users can only access their own devices
- Auto-cleanup of invalid tokens
- Service role can send notifications

**workout_sessions & session_members:**
- Public read for active sessions
- Users can modify their own memberships
- Host-only for session cancellation

### Authentication

- JWT tokens with 15-minute expiry
- Refresh tokens for session continuity
- Email and Phone OTP options
- Automatic profile creation on signup

---

## 📁 Project Structure

```
gym-buddy/
├── android/                  # Android-specific files
├── ios/                      # iOS-specific files
├── lib/                      # Flutter source code
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   ├── services/
│   └── widgets/
├── supabase/                 # Supabase configuration
│   ├── functions/           # Edge Functions (auto-deployed)
│   └── migrations/          # Database migrations
├── docs/                    # Documentation
│   ├── api/                # API documentation
│   │   ├── auth-api-documentation.md
│   │   ├── crud-api-documentation.md
│   │   └── AUTH-QUICK-REFERENCE.md
│   ├── database/           # Database documentation
│   │   └── database-schema.md
│   └── setup/              # Setup guides
├── .env                    # Environment variables (not in git)
├── .env.example            # Environment template
├── README.md               # This file
└── pubspec.yaml            # Flutter dependencies
```

---

## 🧪 Testing

### API Testing

```bash
# Make script executable
chmod +x test-crud-api.sh

# Run tests
./test-crud-api.sh
```

### Manual Testing with cURL

```bash
# 1. Sign up and get token
RESPONSE=$(curl -s -X POST "$BASE_URL/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User"}')

# 2. Get user profile
curl -X GET "$BASE_URL/users-get-me" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 3. List gyms
curl -X GET "$BASE_URL/gyms-list" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 4. Create session
curl -X POST "$BASE_URL/sessions-create" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gym_id": 1,
    "title": "Morning Push",
    "session_type": "push",
    "start_time": "2026-02-10T10:00:00Z",
    "duration_minutes": 60
  }'
```

---

## 🚀 Deployment

### Production Checklist

- [ ] Remove test endpoints (`auth-test-signup`, `auth-email-test-signup`)
- [ ] Configure production SMS provider (Twilio/Vonage)
- [ ] Set up production Firebase project
- [ ] Configure FCM server key in Supabase secrets
- [ ] Enable RLS on all tables
- [ ] Set up proper CORS origins
- [ ] Configure rate limiting
- [ ] Set up monitoring and logging

### Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy

# Or deploy specific function
supabase functions deploy sessions-join
```

### Database Migrations

```bash
# Create migration
supabase migration new add_new_feature

# Apply migrations
supabase migration up

# Reset database (caution!)
supabase db reset
```

---

## 📖 Documentation

- **[API Documentation](docs/api/)** - Complete API reference
- **[Database Schema](docs/database/database-schema.md)** - Database structure
- **[Authentication Guide](docs/api/auth-api-documentation.md)** - Auth flow details
- **[Implementation Summary](docs/CRUD-IMPLEMENTATION-SUMMARY.md)** - What's been built

---

## 💰 Cost Analysis

| Component | Free Tier | Paid Tier | Notes |
|-----------|-----------|-----------|-------|
| **Supabase** | 500K requests/mo | $0.00325/request | Auth, DB, Functions |
| **Firebase FCM** | 1M notifications/day | - | Push notifications |
| **Email Auth** | 500 emails/day | - | Via Gmail SMTP |
| **Phone Auth** | - | $0.01-0.10/SMS | Via Twilio/Vonage |

**Recommendation:** Use Email OTP for MVP (completely FREE!)

---

## 🛣️ Roadmap

### Phase 1: MVP (Current) ✅
- ✅ Authentication (Email/Phone OTP)
- ✅ User profiles
- ✅ Gym discovery
- ✅ Session creation/joining
- ✅ Push notifications

### Phase 2: Enhanced Features
- [ ] Real-time session updates
- [ ] In-app messaging
- [ ] Profile photos
- [ ] Ratings and reviews
- [ ] Session reminders

### Phase 3: GPS & Verification
- [ ] Geofencing
- [ ] Passive check-in
- [ ] Streak tracking
- [ ] Attendance validation

### Phase 4: Scale
- [ ] Multi-city support
- [ ] Gym partnerships
- [ ] Premium features
- [ ] Analytics dashboard

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

For issues and questions:

- Check [docs/](docs/) for documentation
- Review [error codes](docs/api/crud-api-documentation.md#error-codes)
- Open an issue on GitHub

---

## 🙏 Acknowledgments

- [Supabase](https://supabase.com) - Backend platform
- [Flutter](https://flutter.dev) - UI framework
- [Firebase](https://firebase.google.com) - Push notifications
- [Project Context](Project-Context.md) - Original research

---

## 📞 Contact

**Project:** Gym Buddy  
**Backend:** Supabase (Project ID: bpfptwqysbouppknzaqk)  
**Region:** ap-south-1 (Mumbai)

---

**Built with ❤️ for fitness enthusiasts**
