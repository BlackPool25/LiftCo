# LiftCo

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
| **UI Framework** | Material Design 3 with custom theming |

### Project Structure

```
lib/
├── blocs/                  # State management (BLoC pattern)
│   └── auth_bloc.dart      # Authentication state & events
├── config/                 # App configuration
│   └── theme.dart          # Premium dark theme with glassmorphism
├── models/                 # Data models
│   └── user.dart           # User model & enums (Gender, Experience, etc.)
├── screens/                # UI screens
│   ├── login_screen.dart   # Glassmorphic login with OTP & OAuth
│   ├── profile_setup_screen.dart  # Multi-step profile wizard
│   └── home_screen.dart    # Dashboard with feature cards
├── services/               # Business logic & API calls
│   └── auth_service.dart   # Supabase auth wrapper
├── widgets/                # Reusable UI components
│   ├── glass_card.dart     # Glassmorphic card widget
│   └── gradient_button.dart # Premium gradient buttons
└── main.dart               # App entry point & routing
```

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
5. **BentoItem** - Grid item for bento-box layouts

---

## 🔐 Authentication Implementation

### Supported Methods

1. **Email Magic Link** - Passwordless email verification via magic link
2. **Phone OTP** - SMS-based verification
3. **Google OAuth** - Sign in with Google
4. **Apple Sign-In** - Sign in with Apple ID

### Auth Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Login     │───▶│ Magic Link  │───▶│   Profile   │
│   Screen    │    │   Sent UI   │    │   Setup     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                                     │
       │ (OAuth)                             ▼
       └────────────────────────────▶ ┌─────────────┐
                                      │    Home     │
                                      │   Screen    │
                                      └─────────────┘
```

**Email Magic Link Flow:**
1. User enters email on login screen
2. `SignInWithEmailRequested` event dispatched
3. Supabase sends magic link email
4. `MagicLinkSent` state emitted → Confirmation UI shown
5. User clicks link in email → redirected back to app
6. `Authenticated` or `NeedsProfileCompletion` state emitted

### BLoC Events & States

**Events:**
- `SignInWithEmailRequested` - Trigger email OTP
- `SignInWithPhoneRequested` - Trigger phone OTP
- `VerifyEmailOTPRequested` - Verify email code
- `VerifyPhoneOTPRequested` - Verify phone code
- `SignInWithGoogleRequested` - Google OAuth
- `SignInWithAppleRequested` - Apple OAuth
- `CompleteProfileRequested` - Submit profile data
- `SignOutRequested` - Log out user

**States:**
- `AuthInitial` - Initial state
- `AuthLoading` - Auth operation in progress
- `OTPSent` - OTP sent (phone), awaiting verification
- `MagicLinkSent` - Magic link sent (email), showing confirmation UI
- `Authenticated` - User logged in with complete profile
- `NeedsProfileCompletion` - User logged in, needs profile setup
- `Unauthenticated` - User not logged in
- `AuthError` - Error occurred

### OAuth Configuration

**For Web Development:**
```bash
flutter run -d chrome --web-port=3000
```

**Required redirect URIs:**
- Web: `http://localhost:3000`
- Android: `com.liftco.liftco://login-callback/`
- iOS: `com.liftco.liftco://login-callback/`

**Android Deep Link Setup (AndroidManifest.xml):**
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.liftco.liftco" android:host="login-callback"/>
</intent-filter>
```

**Supabase Dashboard Configuration:**
1. Go to Authentication → URL Configuration
2. Add `com.liftco.liftco://login-callback/` to Redirect URLs

---

## 🛡️ Women Safety Feature

LiftCo prioritizes user safety with a comprehensive women-only session feature that creates safe spaces for female users.

### Features

**1. Women-Only Sessions**
- Female users can create sessions exclusively for women
- Sessions marked with "Women Only" badge (pink/purple gradient)
- Only visible to female users in the app
- RLS policies enforce gender-based access control at database level

**2. Female-Only Mode Toggle**
- Quick toggle button in home screen app bar (top right, female users only)
- When enabled, shows only women-only sessions
- Toggle states: "All" (shows all sessions) / "Women" (women-only only)
- Pink/purple gradient styling when active

**3. Session Creation**
- Female users see "Session Type" toggle when creating sessions
- Options: "General Session" (open to all) or "Women Only" (female-only)
- Visual indicator with female icon and descriptive text
- Switch control with pink accent colors

**4. Visual Indicators**
- Women-only sessions display badge in session cards
- Badge shows female icon + "Women" text
- Pink/purple gradient styling consistent across UI
- Badge appears next to session type in card listings

**5. Security & Privacy**
- **RLS Policy**: Only female users can see women_only = true sessions
- **RLS Policy**: Only female users can create women-only sessions
- **RLS Policy**: Only female users can join women-only sessions
- Database-level enforcement prevents unauthorized access

### Database Schema

**workout_sessions.women_only** (boolean, default: false)
- Marks session as women-only when true
- Indexed for query performance
- Enforced by RLS policies

**Users Table Gender Field**
- Required for women-only feature enforcement
- Values: 'male', 'female', 'non_binary', 'prefer_not_to_say'
- Only 'female' users can create/join women-only sessions

### Implementation Details

**Files Modified:**
- `supabase/migrations/20250210200000_add_women_safety_feature.sql` - Database migration
- `lib/models/workout_session.dart` - Added womenOnly field
- `lib/screens/create_session_screen.dart` - Added women-only toggle UI
- `lib/screens/home_tab.dart` - Added female-only mode toggle and filtering
- `lib/services/session_service.dart` - Updated createSession with womenOnly parameter
- `lib/services/gym_service.dart` - Updated queries to respect women-only sessions

**Security:**
All access control enforced at database level via Row Level Security policies:
- SELECT: Women-only sessions only visible to female users
- INSERT: Only female users can create women-only sessions
- session_members INSERT: Only female users can join women-only sessions

---

## 🗄️ Database Schema

### Supabase Project

**Project ID:** `bpfptwqysbouppknzaqk`

### Tables

#### `users`
| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, default: `gen_random_uuid()` |
| `name` | varchar | NOT NULL |
| `email` | varchar | UNIQUE, nullable |
| `phone_number` | varchar | UNIQUE, nullable |
| `age` | integer | CHECK: 13-120, nullable |
| `gender` | varchar | nullable |
| `experience_level` | enum | beginner, intermediate, advanced |
| `preferred_time` | varchar | early_morning, morning, afternoon, evening |
| `current_workout_split` | varchar | See workout splits below |
| `time_working_out_months` | integer | nullable |
| `bio` | text | nullable |
| `reputation_score` | integer | default: 100, CHECK: 0-100 |
| `home_gym_id` | bigint | FK → gyms.id |
| `profile_photo_url` | varchar | nullable |
| `created_at` | timestamptz | default: now() |
| `updated_at` | timestamptz | default: now() |

**Workout Split Values:**
| Value | Label | Description |
|-------|-------|-------------|
| `ppl` | Push Pull Legs | 3-6 day PPL split |
| `upper_lower` | Upper/Lower | 4 day upper/lower split |
| `bro_split` | Bro Split | 5 day body part split |
| `full_body` | Full Body | 2-3 day full body |
| `arnold` | Arnold Split | Chest/Back, Shoulders/Arms, Legs |
| `phul` | PHUL | Power Hypertrophy Upper Lower |
| `phat` | PHAT | Power Hypertrophy Adaptive Training |
| `strength` | Strength/Powerlifting | Focus on compound lifts |
| `cardio_focused` | Cardio Focused | Primarily cardiovascular |
| `crossfit` | CrossFit | High-intensity functional movements |
| `yoga` | Yoga/Mobility | Flexibility focus |
| `hybrid` | Hybrid | Mixed approach |
| `other` | Other | Custom routines |

**Constraints:**
- `valid_contact_info`: Either `email` OR `phone_number` must be provided

#### `user_devices`
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | PK, auto-generated |
| `user_id` | uuid | FK → users.id |
| `fcm_token` | varchar | Firebase Cloud Messaging token |
| `device_type` | varchar | web, android, ios |
| `device_name` | varchar | Device model/browser info |
| `is_active` | boolean | Whether device is active |
| `last_seen_at` | timestamptz | Last activity timestamp |
| `created_at` | timestamptz | When device was registered |

**Device Registration Flow:**
- Devices are automatically registered when a user logs in (OAuth, Magic Link, or OTP)
- Devices are deactivated when the user logs out
- FCM tokens are used for push notifications

#### `gyms`
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | PK (identity) |
| `name` | varchar | Gym name |
| `latitude` | numeric | GPS latitude (-90 to 90) |
| `longitude` | numeric | GPS longitude (-180 to 180) |
| `address` | text | Physical address |
| `opening_days` | int[] | Days open (1-7) |
| `opening_time` | time | Opening time |
| `closing_time` | time | Closing time |
| `phone` | varchar | Contact number |
| `email` | varchar | Contact email |
| `amenities` | text[] | Available amenities |

#### `workout_sessions`
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | PK |
| `gym_id` | bigint | FK → gyms.id |
| `host_user_id` | uuid | FK → users.id |
| `title` | varchar | Session title |
| `session_type` | varchar | Workout type for the session |
| `description` | text | Session details |
| `start_time` | timestamptz | Must be in future |
| `duration_minutes` | integer | 1-480 minutes |
| `max_capacity` | integer | 1-20 (default: 4) |
| `current_count` | integer | Current participants |
| `status` | enum | upcoming, in_progress, finished, cancelled |
| `women_only` | boolean | Women-only session flag (default: false) |

#### `session_members`
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | PK |
| `session_id` | bigint | FK → workout_sessions |
| `user_id` | uuid | FK → users.id |
| `status` | varchar | joined, cancelled, completed, no_show |
| `joined_at` | timestamptz | When user joined |

### Row Level Security (RLS)

All tables have RLS enabled. Users can only:
- Read their own profile data
- Update their own profile
- Read public gym information
- Create/join sessions at their home gym
- Manage their own device registrations

---

## 📱 Screen Implementations

### Login Screen
- Glassmorphic card with animated gradient orbs background
- Toggle between Email and Phone input
- **Magic Link Confirmation UI** - Full-width centered layout with:
  - Gradient icon badge
  - Email highlighted in styled pill
  - Back to login & Resend link options
- Individual OTP digit boxes (6 digits) for phone verification
- Google and Apple OAuth buttons
- Smooth entrance animations with stagger

**LoginScreen Widget Props:**
- `magicLinkEmail` (optional) - If provided, shows magic link confirmation UI

### Profile Setup Screen
- 4-step wizard with animated progress bar
- **Step 1**: Name, Age, Gender selection
- **Step 2**: Experience level cards with icons
- **Step 3**: Preferred time grid (gradient cards)
- **Step 4**: Workout split chips, Bio textarea
- Glassmorphic selection cards with checkmarks

### Home Screen
- Glassmorphic app bar with notification bell
- Feature card with mesh gradient (hero section)
- Quick action chips (Nearby Gyms, Schedule, Buddies)
- Stats grid (Reputation, Level, Preferred Time)
- Upcoming sessions list with empty state
- Floating action button for new sessions

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
| `supabase_flutter` | ^2.8.4 | Supabase client |
| `flutter_bloc` | ^8.1.6 | State management |
| `go_router` | ^15.1.2 | Navigation |
| `flutter_animate` | ^4.5.2 | Animations |
| `google_fonts` | ^6.2.1 | Typography |
| `font_awesome_flutter` | ^10.8.0 | Icons |
| `flutter_dotenv` | ^5.2.1 | Environment variables |

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

### Database Constraint Errors
- `valid_phone` error: Fixed by `allow_email_or_phone_contact` migration
- `age NOT NULL` error: Fixed by making age nullable

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
