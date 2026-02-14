# LiftCo - Gym Buddy Coordination App

A session-based gym buddy coordination app with passive GPS verification, built with Flutter and Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-181818?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)

## 📱 Overview

LiftCo helps fitness enthusiasts find workout partners at their specific gym through session-based matching. Unlike dating apps, it focuses purely on fitness accountability and safety.

### Key Features

- **Session-Based Matching** - Join specific workout sessions instead of permanent buddy matching
- **Women Safety Feature** - Women-only sessions with gender-based access control and privacy protection
- **Anti-Dating Design** - Stats-first profiles, no swiping, contextual chat only
- **Multiple Authentication Options** - Email OTP, Phone OTP, Google OAuth, Apple Sign-In
- **Visual Profile Setup** - Interactive cards for selecting workout preferences instead of boring dropdowns
- **Real-time Notifications** - Push notifications when users join sessions
- **Smart Validation** - Time conflict detection, capacity management
- **Secure by Design** - Row Level Security (RLS) policies protect all user data
- **Premium Dark UI** - Glassmorphism effects, gradient accents, modern typography

---

## 🏗️ Architecture

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.x (Dart) |
| **State Management** | flutter_bloc (BLoC pattern) |
| **Backend** | Supabase (PostgreSQL, Auth, Storage) |
| **Authentication** | Supabase Auth (OTP, OAuth) |
| **API Layer** | Supabase Edge Functions (Deno/TypeScript) |
| **UI Framework** | Material Design 3 with custom theming |

### Project Structure

```
lib/
├── blocs/                      # State management (BLoC pattern)
│   └── auth_bloc.dart          # Authentication state & events
├── config/                     # App configuration
│   └── theme.dart              # Premium dark theme with glassmorphism
├── models/                     # Data models
│   ├── user.dart               # User model & enums (Gender, Experience, etc.)
│   ├── workout_session.dart    # Session model with members
│   └── gym.dart                # Gym model
├── screens/                    # UI screens
│   ├── login_screen.dart       # Glassmorphic login with OTP & OAuth
│   ├── profile_setup_screen.dart   # Multi-step profile wizard
│   ├── home_screen.dart        # Main dashboard
│   ├── home_tab.dart           # Home tab with sessions list
│   ├── gyms_screen.dart        # Gyms listing
│   ├── gym_details_screen.dart # Gym details with sessions
│   ├── schedule_screen.dart    # User's joined sessions
│   ├── session_details_screen.dart   # Session details with members
│   ├── create_session_screen.dart    # Create new session
│   └── settings_screen.dart    # User settings
├── services/                   # Business logic & API calls
│   ├── supabase_service.dart   # Generic CRUD service for Edge Functions
│   ├── session_service.dart    # Session operations
│   ├── session_service_refactored.dart   # Edge Function based sessions
│   ├── gym_service.dart        # Gym operations
│   ├── user_service.dart       # User profile operations
│   └── auth_service.dart       # Supabase auth wrapper
├── widgets/                    # Reusable UI components
│   ├── glass_card.dart         # Glassmorphic card widget
│   ├── gradient_button.dart    # Premium gradient buttons
│   └── bottom_nav_bar.dart     # Floating navigation
└── main.dart                   # App entry point & routing
```

---

## 🔧 Backend Architecture

### Edge Functions (CRUD Operations)

All backend operations are exposed through Supabase Edge Functions following RESTful conventions:

#### Authentication Functions
| Function | Method | Description |
|----------|--------|-------------|
| `auth-request-otp` | POST | Request phone OTP |
| `auth-verify-otp` | POST | Verify phone OTP |
| `auth-email-request-otp` | POST | Request email OTP |
| `auth-email-verify-otp` | POST | Verify email OTP |
| `auth-complete-profile` | POST | Complete user profile |

#### User Functions
| Function | Method | Description | Version |
|----------|--------|-------------|---------|
| `users-get-me` | GET | Get current user profile with retry logic | v6 |
| `users-update-me` | PATCH | Update current user profile | v6 |

**Key Improvements:**
- ✅ **Dual Lookup**: Searches by auth_id, email, or phone number
- ✅ **Auto-sync**: Updates auth_id if profile found by contact info
- ✅ **Complete Profile**: Returns full user data including photos
- ✅ **Auth Consistency**: Ensures auth.users.id matches public.users.auth_id

#### Gym Functions
| Function | Method | Description |
|----------|--------|-------------|
| `gyms-list` | GET | List all gyms with optional search |
| `gyms-get` | GET | Get single gym details |

#### Session Functions
| Function | Method | Description | Version |
|----------|--------|-------------|---------|
| `sessions-list` | GET | List sessions with filters (gym_id, status, date range) | v11 |
| `sessions-get` | GET | Get single session with members, ages & photos | v14 |
| `sessions-create` | POST | Create new session (auto-joins host) | v8 |
| `sessions-delete` | DELETE | Cancel session (host only) | v6 |
| `sessions-join` | POST | Join a session + notify members | v12 |
| `sessions-leave` | POST | Leave a session + notify members | v13 |

**Key Improvements:**
- ✅ **Retry Logic**: All functions retry on transient failures
- ✅ **Profile Resolution**: Fallback lookup by auth_id, email, or phone
- ✅ **Auto-sync**: Updates auth_id if profile found by contact
- ✅ **Notifications**: Automatic push notifications to relevant members
- ✅ **Rate Limit Resilience**: Handles 429 errors gracefully

#### Device & Notification Functions
| Function | Method | Description |
|----------|--------|-------------|
| `devices-register` | POST | Register device for push notifications |
| `devices-remove` | POST | Remove device registration |
| `notifications-send` | POST | Send push notification |

### Database Triggers

#### Session Member Count Management
Automatic count management via PostgreSQL triggers:

```sql
-- Trigger: update_session_count_on_member_insert
-- Automatically increments current_count when member joins

-- Trigger: update_session_count_on_member_update
-- Adjusts count when member status changes (joined/cancelled)
```

**Why Triggers?**
- Prevents count desynchronization between `session_members` table and `current_count` field
- Ensures ACID compliance - count updates are part of the same transaction
- No application-level race conditions

### Row Level Security (RLS) Policies

All tables have RLS enabled with the following policies:

#### workout_sessions
- **SELECT**: Users can see public sessions or women-only sessions (if female)
- **INSERT**: Users can create sessions (women-only only if female)
- **UPDATE**: Only host can update their sessions

#### session_members
- **SELECT**: All authenticated users can see members
- **INSERT**: Users can join sessions (women-only only if female)
- **UPDATE**: Users can only update their own membership status

---

## 🎨 UI/UX Design System

### Theme Configuration

The app uses a premium dark aesthetic with glassmorphism effects.

**Color Palette:**
| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0F` | Main app background |
| Surface | `#15151A` | Cards, inputs |
| Primary Orange | `#E8956A` | Primary actions, gradients |
| Primary Coral | `#F0A878` | Gradient accents |
| Primary Teal | `#4ECDC4` | Secondary highlights |
| Text Primary | `#F8FAFC` | Main text |
| Text Secondary | `#94A3B8` | Subtitles, hints |

**Typography:**
- **Headings**: Plus Jakarta Sans (600-700 weight)
- **Body**: Inter (400-500 weight)

**Key UI Components:**

1. **GlassCard** - Backdrop blur container with translucent background
2. **FeatureCard** - Gradient card with mesh-style colors
3. **GradientButton** - Button with gradient background and glow effect
4. **OAuthButton** - Social sign-in buttons with icons
5. **SessionCard** - Displays session info with status tags

---

## 🔐 Authentication Flow

### Supported Methods

1. **Email OTP** - Passwordless email verification via magic link
2. **Phone OTP** - SMS-based verification
3. **Google OAuth** - Sign in with Google
4. **Apple Sign-In** - Sign in with Apple ID

### Auth Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Login     │───▶│  OTP Sent   │───▶│   Profile   │
│   Screen    │    │   Screen    │    │   Setup     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                                     │
       │ (OAuth)                             ▼
       └────────────────────────────▶ ┌─────────────┐
                                      │    Home     │
                                      │   Screen    │
                                      └─────────────┘
```

**Profile Setup Steps:**
1. **Step 1**: Name, Age, Gender selection
2. **Step 2**: Experience level cards with icons
3. **Step 3**: Preferred time grid (gradient cards)
4. **Step 4**: Workout split chips, Bio textarea

---

## 🏋️ Session Management Flow

### Creating a Session

```
User (Host)
    │
    ▼
Create Session Screen
    │
    ├──▶ Select Gym
    ├──▶ Enter Title & Type
    ├──▶ Select Date & Time
    ├──▶ Set Max Capacity (2-10)
    ├──▶ [Female Only] Toggle Women-Only
    └──▶ Create
              │
              ▼
    ┌─────────────────────────────┐
    │  sessions-create Edge Func  │
    │                             │
    │  1. Create session with     │
    │     current_count = 0       │
    │  2. Add host to             │
    │     session_members         │
    │  3. TRIGGER: auto-increment │
    │     current_count to 1      │
    └─────────────────────────────┘
              │
              ▼
    Session Created Successfully
```

**Key Points:**
- Host is automatically joined to the session
- Database trigger manages count (prevents double-counting)
- Session appears in host's schedule immediately

### Joining a Session

```
User (Participant)
    │
    ▼
Browse Sessions (Home/Gym)
    │
    ├──▶ View Session Details
    │        └──▶ See Host & Members
    │
    └──▶ Click "Join Session"
              │
              ▼
    ┌─────────────────────────────┐
    │   sessions-join Edge Func   │
    │                             │
    │  1. Check: Not already      │
    │     joined                  │
    │  2. Check: Session not full │
    │  3. Check: No time conflicts│
    │  4. Insert member record    │
    │  5. TRIGGER: Increment      │
    │     current_count           │
    └─────────────────────────────┘
              │
              ▼
    Joined Successfully
    Shows "Already Joined" button
```

**Validation Checks:**
- ✅ User not already joined
- ✅ Session has available spots
- ✅ No time conflicts with other joined sessions
- ✅ Session is upcoming (not started/cancelled)

### Leaving a Session

```
User (Participant)
    │
    ▼
Schedule Screen
    │
    ├──▶ Swipe to Leave
    │
    └──▶ Confirm Leave
              │
              ▼
    ┌─────────────────────────────┐
    │  sessions-leave Edge Func   │
    │                             │
    │  1. Check: User is member   │
    │  2. Check: User is not host │
    │  3. Update status to        │
    │     'cancelled'             │
    │  4. TRIGGER: Decrement      │
    │     current_count           │
    └─────────────────────────────┘
              │
              ▼
    Left Successfully
```

### Cancelling a Session (Host Only)

```
Host
    │
    ▼
Session Details
    │
    └──▶ Click "Cancel Session"
              │
              ▼
    ┌─────────────────────────────┐
    │ sessions-delete Edge Func   │
    │                             │
    │  1. Check: User is host     │
    │  2. Cancel all memberships  │
    │  3. Set status to           │
    │     'cancelled'             │
    └─────────────────────────────┘
              │
              ▼
    Session Cancelled
    All members notified
```

---

## 👥 Member Management

### Displaying Members

Session details show all members with their status:

**Member Cards Display:**
- Avatar with initial
- Name
- Joined time (e.g., "2h ago")
- **Host** badge (for session creator)
- **You** badge (for current user)

**Privacy:**
- Only joined members see full member list
- Host always visible to participants
- RLS ensures users can only see members of sessions they can access

### Member States

| Status | Description | Visible To |
|--------|-------------|------------|
| `joined` | Active member | All session participants |
| `cancelled` | Left session | Host only |
| `completed` | Session finished | Host only |
| `no_show` | Didn't attend | Host only |

---

## 🛡️ Women Safety Feature

### Women-Only Sessions

**Creating:**
- Only female users can create women-only sessions
- Toggle appears in create form for female users only
- Sessions marked with pink/purple gradient badge

**Visibility:**
- Women-only sessions only visible to female users
- Enforced at database level via RLS policies
- "Women Only" badge shown on all session cards

**Filter:**
- Female users can toggle between "All" and "Women" sessions
- Toggle in Home tab app bar and Gym details screen

### Gender Verification

Gender is stored in user profile and verified at:
- Session creation (can only create women-only if female)
- Session visibility (RLS policy filters)
- Joining (can only join women-only if female)

---

## 📊 User Stats & Profile

### Home Tab Stats

Three compact stats displayed:

1. **Reputation** - User reputation score (0-100)
2. **Level** - Experience level (Beginner, Intermediate, Advanced)
3. **Preferred Time** - Workout preference (Early Bird, Morning, Afternoon, Evening)

### Editing Preferred Time

```
User
    │
    ▼
Click Preferred Time Card
    │
    ▼
Bottom Sheet Opens
    │
    ├──▶ Select New Time
    │        └──▶ Immediate UI update (local state)
    │        └──▶ API call to update
    │        └──▶ Show success/error
    │
    └──▶ Click "Done" to close
              (or tap outside)
```

**Key Features:**
- Real-time UI feedback
- Doesn't close on selection
- Shows checkmark for selected option
- Animated transitions

---

## 🔄 Data Flow & State Management

### CRUD Service Pattern

All API calls go through standardized service layer with advanced error handling:

```dart
// Generic CRUD Service with Retry Logic
class SupabaseService {
  // Synchronized token refresh prevents 429 errors
  static final Lock _refreshSessionLock = Lock();
  static Future<Session?>? _globalRefreshSessionFuture;
  
  Future<Map<String, dynamic>> get(String function, {params});
  Future<Map<String, dynamic>> post(String function, {body});
  Future<Map<String, dynamic>> patch(String function, {body});
  Future<Map<String, dynamic>> delete(String function, {params});
  
  // Automatic retry on 429 rate limit
  Future<Map<String, dynamic>> _invoke(...) async {
    if (response.statusCode == 429 && retryOnRateLimit) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _invoke(..., retryOnRateLimit: false);
    }
  }
}

// Session Service with Retry Logic
class SessionService {
  Future<List<WorkoutSession>> listSessions({...});
  Future<WorkoutSession> createSession({...});
  Future<void> joinSession(String id);  // 3 retries on failure
  Future<void> leaveSession(String id); // 3 retries on failure
}
```

### Benefits:
- **Consistency** - Same pattern across all features
- **Testability** - Easy to mock service layer
- **Maintainability** - Changes in one place affect all
- **Error Handling** - Centralized error handling with retry logic
- **Rate Limit Protection** - Synchronized token refresh prevents 429s
- **Resilience** - Automatic retry on transient failures

---

## 📱 Screen Flows

### Home Tab

```
┌─────────────────────────────────────┐
│  Hey, [Name]! 👋                    │
│  Ready to crush your workout?       │
├─────────────────────────────────────┤
│  [Rep] [Level] [Preferred Time ▼]  │
├─────────────────────────────────────┤
│  Explore Sessions >                 │
├─────────────────────────────────────┤
│  Available Sessions      [Filter]   │
│  ┌───────────────────────────────┐ │
│  │ 🏋️ Session Title         Joined│ │
│  │ [Gym] [Open] [Women] [Today]   │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 🏋️ Another Session       Open │ │
│  │ [Gym] [2 spots left]          │ │
│  └───────────────────────────────┘ │
│              [Load More]            │
└─────────────────────────────────────┘
```

### Gym Details

```
┌─────────────────────────────────────┐
│  < Gym Name                         │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │        [Gym Image]            │ │
│  │  Gym Name                     │ │
│  │  📍 Address                   │ │
│  │  🕐 Hours                     │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│  Available Sessions    [All▼]       │
│  ┌───────────────────────────────┐ │
│  │ Session Title          [Women]│ │
│  │ [Push Pull Legs] [Today 6PM]  │ │
│  │ Host: Sarah        2 spots    │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│     [+ Create Session]              │
└─────────────────────────────────────┘
```

### Schedule Tab

```
┌─────────────────────────────────────┐
│  Your Schedule                      │
│  Manage your upcoming sessions      │
├─────────────────────────────────────┤
│  [Upcoming: 3]    [Today: 1]       │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ 🏋️ Morning Push Day      Host │ │
│  │ [Push Pull Legs] [Women Only] │ │
│  │ ───────────────────────────── │ │
│  │ 📅 Today  🕐 6:00-7:00 AM     │ │
│  │ 👥 3/4 members                │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 🏋️ Leg Day Session     Joined │ │
│  │ [Legs]                        │ │
│  │ ───────────────────────────── │ │
│  │ 📅 Tomorrow  🕐 5:00-6:00 PM  │ │
│  │ 👥 2/6 members                │ │
│  └───────────────────────────────┘ │
│  (Swipe to leave)                   │
└─────────────────────────────────────┘
```

### Session Details

```
┌─────────────────────────────────────┐
│  < Session Details                  │
├─────────────────────────────────────┤
│  [Push Pull Legs] [upcoming]        │
│  Morning Push Day                   │
│  Focus on chest, shoulders, triceps │
│  ────────────────────────────────── │
│  📅 Today                           │
│  🕐 6:00 AM - 7:00 AM               │
│  ⏱️ 60 minutes                      │
│  ────────────────────────────────── │
│  👤 Host: Sarah          2 spots    │
├─────────────────────────────────────┤
│  Members (3/4)                      │
│  ┌───────────────────────────────┐ │
│  │ 👤 Sarah               HOST   │ │
│  │ Joined 2h ago                 │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 👤 Mike                       │ │
│  │ Joined 1h ago                 │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 👤 You                 YOU    │ │
│  │ Joined 30m ago                │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│  [✓ You've Joined]                  │
│  [Cancel Session]      (Host only)  │
│  [Leave Session]       (Member only)│
│  [Join Session]        (New user)   │
└─────────────────────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/)
- A Supabase project

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "Gym Buddy"
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   
   Create `.env` file:
   ```bash
   SUPABASE_URL=https://bpfptwqysbouppknzaqk.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

4. **Run the app**
   ```bash
   # For web development (with fixed port for OAuth)
   flutter run -d chrome --web-port=3000
   
   # For Android/iOS
   flutter run
   ```

---

## 🔧 Development Commands

```bash
# Run on Chrome with OAuth support
flutter run -d chrome --web-port=3000

# Check code health
flutter analyze

# Format code
dart format .

# Clean and rebuild
flutter clean && flutter pub get

# Build release APK
flutter build apk --release

# Build for web
flutter build web --release
```

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.8.0 | Supabase client |
| `synchronized` | ^3.1.0 | Thread-safe locking for token refresh |
| `shared_preferences` | ^2.3.4 | Local profile caching |
| `http` | ^1.2.0 | HTTP client for Edge Functions |
| `flutter_bloc` | ^8.1.6 | State management |
| `go_router` | ^15.1.2 | Navigation |
| `flutter_animate` | ^4.5.2 | Animations |
| `google_fonts` | ^6.2.1 | Typography |
| `font_awesome_flutter` | ^10.8.0 | Icons |
| `flutter_dotenv` | ^5.2.1 | Environment variables |
| `firebase_core` | ^3.1.0 | Firebase core |
| `firebase_messaging` | ^15.0.0 | Push notifications |

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

---

## 📱 Supported Platforms

| Platform | Minimum Version | OAuth Support |
|----------|-----------------|---------------|
| Android | API 21 (5.0) | ✅ Google, Apple |
| iOS | iOS 12.0 | ✅ Google, Apple |
| Web | Modern browsers | ✅ Google |

---

## 🆘 Troubleshooting

### OAuth Redirect Issues
- Ensure running on port 3000 for web: `flutter run -d chrome --web-port=3000`
- Add `http://localhost:3000` to Google Cloud Console redirect URIs
- Configure Supabase dashboard with redirect URLs

### Database Issues
- **Count Mismatch**: Database triggers should auto-fix. Run migration if needed:
  ```sql
  SELECT * FROM information_schema.triggers 
  WHERE trigger_name LIKE 'update_session_count%';
  ```
- **RLS Policy Errors**: Ensure migrations have been applied

### Build Issues
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📄 License

This project is licensed under the MIT License.

---

**Built with ❤️ for fitness enthusiasts**

## Recent Changes & Updates

### Authentication & Session Management (MAJOR UPDATE)
- ✅ **Synchronized Token Refresh**: Prevents 429 rate limits with global locks
- ✅ **Rate Limit Handling**: Automatic retry with exponential backoff
- ✅ **Grace Periods**: 3-second delays prevent false logouts during operations
- ✅ **Profile Caching**: Local cache reduces API calls and improves cold start
- ✅ **Retry Logic**: Join/Leave operations retry 3 times on transient failures
- ✅ **Explicit Sign-out Tracking**: Prevents accidental logouts from race conditions
- ✅ **AuthBloc Improvements**: Better state handling with fallback mechanisms

### Session Management Fixes
- ✅ Fixed session member counting with database triggers
- ✅ Added "Already Joined" button state
- ✅ Host can now cancel sessions
- ✅ Members can leave sessions with swipe gesture
- ✅ Members list properly displays with names
- ✅ Retry mechanism for join/leave operations

### UI/UX Improvements
- ✅ Fixed preferred time picker with real-time updates
- ✅ Fixed training level display (shows full word)
- ✅ Removed reputation score from top app bar
- ✅ Added status tags (Joined, Open, Women Only)
- ✅ Implemented pagination with "Load More"
- ✅ Displayed gym names on session cards (Home/Schedule) and in Session Details
- ✅ Added Home tab gym filter with server-side session refresh
- ✅ Added LiftCo logo + app name to Home and Login screens
- ✅ Updated female-only toggles to sliding switches (Home/Gym Details)

### Architecture Improvements
- ✅ Created generic CRUD service for Edge Functions
- ✅ Refactored session service to use Edge Functions
- ✅ Standardized API error handling
- ✅ Added comprehensive type safety
- ✅ **Added synchronized package** for thread-safe operations
- ✅ **Added retry logic** throughout session operations

### Database Updates
- ✅ **Member Count Triggers Fixed**: Added INSERT, UPDATE, and DELETE triggers on `session_members` table to automatically sync `current_count` with actual joined members
- ✅ **Fixed session_members schema** with proper UUID types
- ✅ **Added women_only column** with RLS policies
- ✅ **Verified all RLS policies** are working correctly
- ✅ **Auto-Complete Sessions**: Cron job marks sessions as `finished` when end time passes
- ✅ **Notification Triggers**: Database triggers notify when members join/leave (for audit/debugging)

### Critical Fix: User ID Comparison
**Problem**: Auth user ID (from `auth.users`) didn't match users table ID (from `public.users`), causing:
- User's name not appearing in members list
- "Join Session" button showing instead of "Leave" even when joined
- Incorrect member detection

**Solution**: Session details screen now queries the `users` table by email/phone to get the correct user ID:
```dart
final response = await Supabase.instance.client
    .from('users')
    .select('id')
    .or('email.eq.${authUser.email},phone_number.eq.${authUser.phone}')
    .single();
_currentUserId = response['id'] as String; // Now matches session_members.user_id
```

### Debug Logging Added
Comprehensive debug logging added to `session_details_screen.dart`:
- User lookup process
- Member comparison (userId vs _currentUserId)
- UI build status (_isUserJoined, _sortedMembers)
- Member tile rendering (showing which member is current user)

**To see debug logs**: Run app with `flutter run` and check console output for `[SessionDetails]` messages.

### Notification System Implementation (FIXED & ENHANCED)
- ✅ **Settings Toggle Fixed**: Now properly checks Firebase permission status + current device token in database. Toggle persists correctly across app restarts.
- ✅ **Join Notifications**: When user A joins a session with users B & C, only B & C receive notification. A is excluded.
- ✅ **Leave Notifications**: When user A leaves, only remaining members (B & C) are notified. A is excluded.
- ✅ **Session Reminders**: Automated reminders at 2 hours and 30 minutes before session start
- ✅ **Smart Delivery**: Only sends to devices with `is_active = true` and valid FCM tokens
- ✅ **Debug Logging**: Added comprehensive logging to track notification delivery

### Session Member Management (REDESIGNED)
- ✅ **New Grid Layout**: Members displayed in 2-column grid tiles with profile photos
- ✅ **Host Section**: Dedicated host tile at top with prominent HOST badge
- ✅ **Age Display**: Members can now see each other's ages (RLS policy updated)
- ✅ **Self Identification**: "YOU" badge on current user's tile
- ✅ **Profile Photos**: Full photo display with initials fallback
- ✅ **Responsive Design**: Clean card-based layout with proper spacing

### Session Listings Enhanced
- ✅ **Host Visibility**: Host name and profile photo now visible in session cards
- ✅ **Women-Only Respect**: Host info only shown for sessions user has permission to view
- ✅ **Better UI**: Host photo shown as session icon with name displayed below title

### New Edge Functions
| Function | Description | Schedule |
|----------|-------------|----------|
| `session-reminders` | Sends reminders 2h & 30min before sessions | Cron (10 min) |
| `session-auto-complete` | Auto-marks sessions as finished when time ends | Cron (5 min) |
| `sessions-join` | Join session + notify existing members (not joiner) | On HTTP call |
| `sessions-leave` | Leave session + notify remaining members (not leaver) | On HTTP call |
| `sessions-get` | Get session with host/member ages & photos | On HTTP call |
| `sessions-list` | List sessions with host profile info | On HTTP call |

### New Edge Functions
| Function | Description | Trigger |
|----------|-------------|---------|
| `session-reminders` | Sends reminder notifications 2 hours and 30 mins before sessions | Cron job (every 10 min) |
| Updated `sessions-join` | Now sends notifications to existing members when someone joins | On session join |
| Updated `sessions-leave` | Now sends notifications when a member leaves | On session leave |
| Updated `sessions-get` | Now includes `profile_photo_url` in member and host data | On session fetch |

### Database Schema Updates
```sql
-- RLS Policy: Allow session members to view each other's profiles
create policy "Allow session members to view each other's profiles"
  on public.users for select to authenticated
  using (
    auth.uid() = id
    or exists (
      select 1 from session_members sm1
      join session_members sm2 on sm1.session_id = sm2.session_id
      where sm1.user_id = auth.uid() and sm2.user_id = users.id
      and sm1.status = 'joined' and sm2.status = 'joined'
    )
  );

-- Cron job for session reminders (runs every 10 minutes)
select cron.schedule('session-reminders-job', '*/10 * * * *', ...);
```

---

## 🔒 Authentication & Session Management (Recent Major Updates)

### Synchronized Token Refresh System

To prevent race conditions and 429 rate limit errors during rapid navigation, we've implemented a **synchronized token refresh mechanism**:

**Problem Solved:**
- Multiple concurrent API calls were triggering simultaneous token refreshes
- Supabase's rate limit (30 requests/minute) was being hit
- Users were getting unexpectedly logged out during session operations

**Solution:**

```dart
// lib/services/supabase_service.dart
class SupabaseService {
  // Global (static) lock ensures ALL instances share one refresh
  static final Lock _refreshSessionLock = Lock();
  static Future<Session?>? _globalRefreshSessionFuture;
  
  Future<Session?> _refreshSessionLocked() async {
    return _refreshSessionLock.synchronized(() {
      // Double-check pattern prevents race conditions
      if (_globalRefreshSessionFuture == null) {
        _globalRefreshSessionFuture = _client.auth.refreshSession()
          .then((response) => response.session)
          .whenComplete(() => _globalRefreshSessionFuture = null);
      }
      return _globalRefreshSessionFuture!;
    });
  }
}
```

**Key Features:**
- ✅ **Thread-safe**: Uses `synchronized` package for cross-instance locking
- ✅ **Global scope**: Static variables ensure single refresh across app
- ✅ **Double-check pattern**: Prevents multiple futures from being created
- ✅ **Automatic cleanup**: Future is cleared after completion

### Rate Limiting & 429 Handling

The app now gracefully handles Supabase rate limits:

```dart
// In _invoke method - handles 429 with retry
if (response.statusCode == 429 && retryOnRateLimit) {
  // Back off briefly and retry once
  await Future.delayed(const Duration(milliseconds: 800));
  return _invoke(functionName, ..., retryOnRateLimit: false);
}
```

**Rate Limit Strategy:**
1. **Prevention**: Synchronized lock prevents concurrent refreshes
2. **Detection**: Checks for 429 status code
3. **Backoff**: 800ms delay before retry
4. **Grace period**: AuthBloc waits 3 seconds before declaring logout

### Improved AuthBloc State Management

Enhanced authentication state handling prevents false logouts:

```dart
Future<void> _onAuthStateChanged(...) async {
  final session = event.authState.session;

  if (session == null) {
    if (_explicitSignOutInProgress) {
      // Real sign-out, proceed normally
      await _authService.clearCachedProfile();
      emit(const Unauthenticated());
      return;
    }

    // Grace period: Supabase can briefly report null during refresh
    await Future.delayed(const Duration(milliseconds: 800));
    if (_authService.isAuthenticated) return;

    // Attempt explicit refresh before giving up
    final refreshed = await _authService.refreshSessionLocked();
    if (refreshed != null) return;

    // Extended grace period for rate limit recovery
    await Future.delayed(const Duration(milliseconds: 2200));
    if (_authService.isAuthenticated) return;

    // Finally logout
    await _authService.clearCachedProfile();
    emit(const Unauthenticated());
  }
}
```

**New Features:**
- ✅ **Explicit sign-out tracking**: `_explicitSignOutInProgress` flag
- ✅ **Grace periods**: 800ms + 2200ms delays prevent false logouts
- ✅ **Retry with refresh**: Attempts session recovery before logout
- ✅ **Cache-first loading**: Shows cached profile while fetching fresh data

### Session Operation Retry Logic

Join/Leave operations now have built-in retry mechanisms:

```dart
// lib/screens/session_details_screen.dart
Future<void> _joinSession() async {
  const maxRetries = 3;
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      await _sessionService.joinSession(_session!.id);
      // Success handling
      break;
    } catch (e) {
      if (attempt == maxRetries - 1) {
        // Show error on final attempt
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
}
```

**Benefits:**
- ✅ **Transient failure recovery**: Network hiccups don't break UX
- ✅ **Exponential backoff**: 300ms between retries
- ✅ **User feedback**: Shows error only after all retries fail

### Profile Caching System

Local profile caching reduces API calls and improves perceived performance:

```dart
// lib/services/auth_service.dart
class AuthService {
  static const _kCachedProfileAuthUid = 'cached_profile_auth_uid';
  static const _kCachedProfileJson = 'cached_profile_json';
  static const _kCachedProfileComplete = 'cached_profile_complete';
  
  Future<void> _cacheUserProfile(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedProfileAuthUid, authUser.id);
    await prefs.setString(_kCachedProfileJson, jsonEncode(user.toJson()));
    await prefs.setBool(_kCachedProfileComplete, user.isProfileComplete);
  }
  
  Future<User?> getCachedUserProfile() async {
    // Returns cached profile only if auth UID matches
    // Prevents showing wrong user's data
  }
}
```

**Features:**
- ✅ **Cold start optimization**: Shows cached profile immediately
- ✅ **Auth UID validation**: Ensures cache belongs to current user
- ✅ **Fallback on failure**: Uses cache if server fetch fails
- ✅ **Auto-update**: Cache refreshed on successful server fetch

### Updated Edge Functions with Retry Logic

All edge functions now include robust error handling and retry mechanisms:

#### sessions-join (v12)
- **Profile resolution retry**: 3 attempts with 120ms delays
- **Auth/contact fallback**: Resolves by auth_id, email, or phone
- **Auto-sync**: Updates auth_id if found by contact
- **Rate limit resilience**: Handles 429 gracefully

```typescript
// Excerpt from sessions-join
let userProfile: any = null;
for (let attempt = 0; attempt < 3; attempt++) {
  userProfile = await resolveProfileByAuthOrContact(serviceClient, user);
  if (userProfile) break;
  if (attempt < 2) {
    await new Promise((resolve) => setTimeout(resolve, 120));
  }
}
```

#### sessions-leave (v13)
- **Atomic operations**: Uses transactions for consistency
- **Notification triggers**: Notifies remaining members
- **Host validation**: Prevents host from leaving (must cancel)

#### sessions-get (v14)
- **Enriched data**: Includes host and member ages, photos
- **Membership status**: Returns user's membership in session
- **Error boundaries**: Handles missing sessions gracefully

#### users-get-me (v6)
- **Profile resolution**: Dual lookup by auth_id or email/phone
- **Auto-sync**: Updates auth_id if mismatched
- **Complete profile data**: Returns full user object with all fields

### Dependencies Updated

| Package | Version | Purpose |
|---------|---------|---------|
| `synchronized` | ^3.1.0 | **NEW** - Thread-safe locking for token refresh |
| `supabase_flutter` | ^2.8.0 | Supabase client |
| `http` | ^1.2.0 | HTTP client for Edge Functions |
| `flutter_bloc` | ^8.1.6 | State management |
| `shared_preferences` | ^2.3.4 | Local profile caching |

### Troubleshooting Authentication Issues

#### Issue: Getting logged out during session operations
**Solution**: The app now has built-in grace periods. If you still experience issues:
1. Check network connectivity
2. Ensure Supabase URL and anon key are correct
3. Verify user profile exists in database

#### Issue: 429 Rate Limit errors in logs
**Solution**: This is expected during rapid navigation. The app now:
1. Retries with exponential backoff
2. Synchronizes token refreshes
3. Waits 3 seconds before declaring logout

#### Issue: "User profile not found" errors
**Solution**: Edge functions now retry profile lookup 3 times. If persistent:
1. Check that `auth_id` is synced in `users` table
2. Verify email/phone matches between auth and users table
3. Check RLS policies allow reading user data

### Testing Authentication Flows

```bash
# Test rapid navigation
1. Login to app
2. Navigate between Home, Gyms, and Schedule tabs rapidly
3. Join and leave sessions quickly
4. Verify you stay logged in

# Test session persistence
1. Login to app
2. Background the app for 10 minutes
3. Foreground and perform actions
4. Verify session is still valid

# Test network resilience
1. Turn on airplane mode
2. Attempt to join session (will fail)
3. Turn off airplane mode
4. Retry operation - should succeed
```
