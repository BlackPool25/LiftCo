# LiftCo

A session-based gym buddy coordination app with passive GPS verification, built with Flutter and Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-181818?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)

## 📱 Overview

LiftCo helps fitness enthusiasts find workout partners at their specific gym through session-based matching. Unlike dating apps, it focuses purely on fitness accountability and safety.

### Key Features

- **Session-Based Matching** - Join specific workout sessions instead of permanent buddy matching
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
| Primary Purple | `#8B5CF6` | Primary actions, gradients |
| Primary Indigo | `#6366F1` | Gradient accents |
| Accent Cyan | `#22D3EE` | Secondary highlights |
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

1. **Email OTP** - Passwordless email verification
2. **Phone OTP** - SMS-based verification
3. **Google OAuth** - Sign in with Google
4. **Apple Sign-In** - Sign in with Apple ID

### Auth Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Login     │───▶│    OTP      │───▶│   Profile   │
│   Screen    │    │  Verify     │    │   Setup     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                                     │
       │ (OAuth)                             ▼
       └────────────────────────────▶ ┌─────────────┐
                                      │    Home     │
                                      │   Screen    │
                                      └─────────────┘
```

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
- `OTPSent` - OTP sent, awaiting verification
- `Authenticated` - User logged in with complete profile
- `NeedsProfileSetup` - User logged in, needs profile
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
| `current_workout_split` | enum | push, pull, legs, full_body, etc. |
| `time_working_out_months` | integer | nullable |
| `bio` | text | nullable |
| `reputation_score` | integer | default: 100, CHECK: 0-100 |
| `home_gym_id` | bigint | FK → gyms.id |
| `profile_photo_url` | varchar | nullable |
| `created_at` | timestamptz | default: now() |
| `updated_at` | timestamptz | default: now() |

**Constraints:**
- `valid_contact_info`: Either `email` OR `phone_number` must be provided

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
| `session_type` | enum | push, pull, legs, etc. |
| `description` | text | Session details |
| `start_time` | timestamptz | Must be in future |
| `duration_minutes` | integer | 1-480 minutes |
| `max_capacity` | integer | 1-20 (default: 4) |
| `current_count` | integer | Current participants |
| `status` | enum | upcoming, in_progress, finished, cancelled |

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

---

## 📱 Screen Implementations

### Login Screen
- Glassmorphic card with animated gradient orbs background
- Toggle between Email and Phone input
- Individual OTP digit boxes (6 digits)
- Google and Apple OAuth buttons
- Smooth entrance animations with stagger

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
