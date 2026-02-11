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
| Function | Method | Description |
|----------|--------|-------------|
| `users-get-me` | GET | Get current user profile |
| `users-update-me` | PATCH | Update current user profile |

#### Gym Functions
| Function | Method | Description |
|----------|--------|-------------|
| `gyms-list` | GET | List all gyms with optional search |
| `gyms-get` | GET | Get single gym details |

#### Session Functions
| Function | Method | Description |
|----------|--------|-------------|
| `sessions-list` | GET | List sessions with filters (gym_id, status, date range) |
| `sessions-get` | GET | Get single session with members |
| `sessions-create` | POST | Create new session (auto-joins host) |
| `sessions-delete` | DELETE | Cancel session (host only) |
| `sessions-join` | POST | Join a session |
| `sessions-leave` | POST | Leave a session |

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

All API calls go through standardized service layer:

```dart
// Generic CRUD Service
class SupabaseService {
  Future<Map<String, dynamic>> get(String function, {params});
  Future<Map<String, dynamic>> post(String function, {body});
  Future<Map<String, dynamic>> patch(String function, {body});
  Future<Map<String, dynamic>> delete(String function, {params});
}

// Specific Services use CRUD
class SessionService {
  Future<List<WorkoutSession>> listSessions({...});
  Future<WorkoutSession> createSession({...});
  Future<void> joinSession(String id);
  Future<void> leaveSession(String id);
}
```

### Benefits:
- **Consistency** - Same pattern across all features
- **Testability** - Easy to mock service layer
- **Maintainability** - Changes in one place affect all
- **Error Handling** - Centralized error handling

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

### Session Management Fixes
- ✅ Fixed session member counting with database triggers
- ✅ Added "Already Joined" button state
- ✅ Host can now cancel sessions
- ✅ Members can leave sessions with swipe gesture
- ✅ Members list properly displays with names

### UI/UX Improvements
- ✅ Fixed preferred time picker with real-time updates
- ✅ Fixed training level display (shows full word)
- ✅ Removed reputation score from top app bar
- ✅ Added status tags (Joined, Open, Women Only)
- ✅ Implemented pagination with "Load More"

### Architecture Improvements
- ✅ Created generic CRUD service for Edge Functions
- ✅ Refactored session service to use Edge Functions
- ✅ Standardized API error handling
- ✅ Added comprehensive type safety

### Database Updates
- ✅ Added triggers for automatic count management
- ✅ Fixed session_members schema with proper UUID types
- ✅ Added women_only column with RLS policies
- ✅ Verified all RLS policies are working correctly
