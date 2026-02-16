# AGENTS.md - LiftCo Gym Buddy App

Guidelines for agentic coding agents working on the LiftCo Gym Buddy App.

## Project Overview

LiftCo is a session-based gym buddy coordination app. Users create/join workout sessions at specific gyms instead of permanent buddy matching. Built with Flutter (frontend) and Supabase (backend).

**Key Features:**
- Session-based workout matching (not dating-app style)
- Women-only sessions with RLS-enforced privacy
- Multiple auth methods (Email OTP, Phone OTP, Google OAuth, Apple Sign-In)
- Real-time push notifications via Firebase
- Premium dark UI with glassmorphism effects

**Future Features:**
- Bluetooth BLE transponder-based attendance tracking (planned)

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.x (Dart) |
| **State Management** | flutter_bloc (BLoC pattern) |
| **Backend** | Supabase (PostgreSQL, Auth, Edge Functions) |
| **API Layer** | Supabase Edge Functions (Deno/TypeScript) |
| **Storage** | Supabase Storage (buckets to be created) |
| **Notifications** | Firebase Cloud Messaging |
| **UI** | Material Design 3 + custom glassmorphism theme |

## Build Commands

### Flutter

```bash
# Install dependencies
flutter pub get

# Run app (hot reload enabled)
flutter run

# Run on specific device
flutter run -d <device_id>

# Run on Chrome with OAuth support (fixed port)
flutter run -d chrome --web-port=3000

# Build for production
flutter build apk --release              # Android
flutter build ios --release              # iOS (requires macOS/Xcode)
flutter build web --release              # Web
flutter build ipa                        # iOS App Store bundle

# Analyze code
flutter analyze
flutter analyze --fatal-infos --fatal-warnings

# Fix auto-fixable issues
flutter fix

# Clean and rebuild
flutter clean && flutter pub get
```

### Testing

```bash
# Run all tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Run specific test by name
flutter test --name "should create session with valid data"

# Run with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

### Code Quality

```bash
# Format all Dart files
 dart format .

# Check formatting (CI)
dart format --output=none --set-exit-if-changed .

# Check for lint issues
flutter analyze
```

### Supabase (Backend)

```bash
# Start local Supabase
supabase start

# Check status
supabase status

# Apply migrations
supabase migration up

# Create new migration
supabase migration new <name>

# Reset local database
supabase db reset

# Stop local Supabase
supabase stop
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── blocs/                         # BLoC state management
│   └── auth_bloc.dart             # Auth state & events
├── config/                        # App configuration
│   └── theme.dart                 # Premium dark theme
├── models/                        # Data models
│   ├── user.dart                  # User model with enums
│   ├── workout_session.dart       # Session model
│   └── gym.dart                   # Gym model
├── screens/                       # UI screens
│   ├── login_screen.dart          # Auth screen
│   ├── profile_setup_screen.dart  # Profile wizard
│   ├── home_screen.dart           # Main dashboard
│   ├── home_tab.dart              # Sessions list
│   ├── gyms_screen.dart           # Gym listings
│   ├── gym_details_screen.dart    # Gym details
│   ├── schedule_screen.dart       # User's sessions
│   ├── session_details_screen.dart # Session details
│   ├── create_session_screen.dart # Create session
│   └── settings_screen.dart       # Settings
├── services/                      # Business logic
│   ├── supabase_service.dart      # Generic CRUD service
│   ├── session_service.dart       # Session operations
│   ├── gym_service.dart           # Gym operations
│   ├── user_service.dart          # User operations
│   └── auth_service.dart          # Auth wrapper
└── widgets/                       # Reusable UI
    ├── glass_card.dart            # Glassmorphism card
    ├── gradient_button.dart       # Gradient button
    └── bottom_nav_bar.dart        # Navigation

supabase/functions/                # Edge Functions
├── auth-request-otp/
├── auth-verify-otp/
├── auth-complete-profile/
├── auth-email-request-otp/
├── auth-email-verify-otp/
├── users-get-me/                  # Get profile (v6)
├── users-update-me/               # Update profile (v6)
├── gyms-list/                     # List gyms
├── gyms-get/                      # Get gym details
├── sessions-list/                 # List sessions (v11)
├── sessions-get/                  # Get session (v14)
├── sessions-create/               # Create session (v8)
├── sessions-delete/               # Cancel session (v6)
├── sessions-join/                 # Join session (v12)
├── sessions-leave/                # Leave session (v13)
├── devices-register/              # Register FCM token
├── devices-remove/                # Unregister device
├── notifications-send/            # Send notification
├── session-reminders/             # Cron: session reminders
└── session-auto-complete/         # Cron: auto-complete sessions
```

## Code Style Guidelines

### Dart/Flutter Conventions

**Naming:**
- Classes: `PascalCase` (e.g., `WorkoutSession`, `SessionCard`)
- Variables/functions: `lowerCamelCase` (e.g., `getUserSessions`, `currentCount`)
- Constants: `lowerCamelCase` or `kPascalCase` (e.g., `apiUrl` or `kApiUrl`)
- Files: `snake_case.dart` (e.g., `session_service.dart`)
- Private members: `_leadingUnderscore` (e.g., `_refreshSessionLock`)
- Enums: `lowercase_with_underscores` (e.g., `session_status`)

**Imports Order:**
```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:convert';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Third-party packages
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 4. Project imports (relative)
import '../models/workout_session.dart';
import '../services/session_service.dart';
```

**Formatting:**
- Always run `dart format .` before committing
- Line length: 80 characters (default)
- Use trailing commas for multi-line lists/parameters
- 2-space indentation

**Types & Null Safety:**
```dart
// Use final for variables that don't change
final String sessionId = session.id;

// Use const for compile-time constants
const int maxRetries = 3;

// Prefer explicit types over var for public APIs
Future<WorkoutSession> getSession(String id) async { ... }

// Use null safety properly
String? optionalName;           // Nullable
late String requiredName;       // Late initialization
required String mustProvide,    // Required parameter
```

**Error Handling:**
```dart
try {
  await _sessionService.joinSession(sessionId);
} on PostgrestException catch (e) {
  debugPrint('Database error: ${e.message}');
  rethrow;
} on AuthException catch (e) {
  debugPrint('Auth error: ${e.message}');
  // Handle auth error
} catch (e, stackTrace) {
  debugPrint('Unexpected error: $e');
  debugPrintStack(stackTrace: stackTrace);
  // Show user-friendly error
}
```

**Widget Structure:**
```dart
class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    super.key,
  });
  
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(session.title),
        subtitle: Text(session.gymName),
      ),
    );
  }
}
```

**BLoC Pattern:**
```dart
// Events
abstract class SessionEvent extends Equatable { ... }
class LoadSessions extends SessionEvent { ... }
class JoinSession extends SessionEvent { 
  final String sessionId;
  const JoinSession(this.sessionId);
}

// States
abstract class SessionState extends Equatable { ... }
class SessionInitial extends SessionState { ... }
class SessionLoaded extends SessionState {
  final List<WorkoutSession> sessions;
  const SessionLoaded(this.sessions);
}

// Bloc
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._service) : super(SessionInitial()) {
    on<LoadSessions>(_onLoadSessions);
  }
}
```

## Database Schema

### Key Tables

**users:**
- `id` (uuid, PK), `auth_id` (uuid, links to auth.users)
- `name`, `email`, `phone_number` (unique)
- `age` (13-120), `gender` (varchar)
- `experience_level` (enum: beginner, intermediate, advanced)
- `current_workout_split` (enum: push, pull, legs, ppl, etc.)
- `preferred_time` (early_morning, morning, afternoon, evening)
- `home_gym_id` (FK to gyms)
- `profile_photo_url`, `bio`
- `reputation_score` (0-100, default 100)

**workout_sessions:**
- `id` (uuid, PK), `gym_id` (bigint, FK)
- `host_user_id` (uuid, FK to users)
- `title`, `description`, `session_type`
- `start_time`, `duration_minutes` (1-480)
- `max_capacity` (1-20, default 4), `current_count`
- `status` (enum: upcoming, in_progress, finished, cancelled)
- `women_only` (boolean, default false)

**session_members:**
- `id` (uuid, PK), `session_id` (uuid, FK)
- `user_id` (uuid, FK), `joined_at`
- `status` (joined, cancelled, completed, no_show)

**gyms:**
- `id` (bigint, PK), `name`, `address`
- `latitude`, `longitude`
- `opening_days` (int[]), `opening_time`, `closing_time`
- `amenities` (text[])

**user_devices:**
- `id` (uuid, PK), `user_id` (uuid, FK)
- `fcm_token`, `device_type`, `device_name`
- `is_active` (boolean)

### RLS Policies

All tables have RLS enabled. Key policies:

**workout_sessions:**
- SELECT: Users can see public sessions or women-only (if female)
- INSERT: Users can create (women-only only if female)
- UPDATE: Only host can update their sessions

**session_members:**
- SELECT: All authenticated users can see members
- INSERT: Users can join (women-only only if female)
- UPDATE: Users can only update their own membership

## Edge Functions API

### Authentication
| Function | Method | JWT | Description |
|----------|--------|-----|-------------|
| `auth-request-otp` | POST | No | Request phone OTP |
| `auth-verify-otp` | POST | No | Verify phone OTP |
| `auth-email-request-otp` | POST | No | Request email OTP |
| `auth-email-verify-otp` | POST | No | Verify email OTP |
| `auth-complete-profile` | POST | Yes | Complete user profile |

### Users
| Function | Method | Version | Description |
|----------|--------|---------|-------------|
| `users-get-me` | GET | v6 | Get current user profile with retry |
| `users-update-me` | PATCH | v6 | Update current user profile |

### Gyms
| Function | Method | Description |
|----------|--------|-------------|
| `gyms-list` | GET | List all gyms with search |
| `gyms-get` | GET | Get single gym details |

### Sessions
| Function | Method | Version | Description |
|----------|--------|---------|-------------|
| `sessions-list` | GET | v11 | List sessions with filters |
| `sessions-get` | GET | v14 | Get session with members & photos |
| `sessions-create` | POST | v8 | Create session (auto-joins host) |
| `sessions-delete` | DELETE | v6 | Cancel session (host only) |
| `sessions-join` | POST | v12 | Join session + notify members |
| `sessions-leave` | POST | v13 | Leave session + notify members |

### Notifications
| Function | Method | JWT | Description |
|----------|--------|-----|-------------|
| `devices-register` | POST | Yes | Register FCM token |
| `devices-remove` | POST | Yes | Remove device |
| `notifications-send` | POST | No | Send push notification |
| `session-reminders` | Cron | - | Reminders 2h & 30min before |
| `session-auto-complete` | Cron | - | Auto-mark finished sessions |

## Architecture Patterns

### CRUD Service Pattern

All API calls use `SupabaseService` with retry logic:

```dart
class SupabaseService {
  // Global lock prevents 429 rate limits
  static final Lock _refreshSessionLock = Lock();
  static Future<Session?>? _globalRefreshSessionFuture;
  
  Future<Map<String, dynamic>> get(String function, {params});
  Future<Map<String, dynamic>> post(String function, {body});
  Future<Map<String, dynamic>> patch(String function, {body});
  Future<Map<String, dynamic>> delete(String function, {params});
}
```

### Retry Logic

Join/Leave operations retry 3 times on transient failures:

```dart
Future<void> _joinSession() async {
  const maxRetries = 3;
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      await _sessionService.joinSession(_session!.id);
      break;
    } catch (e) {
      if (attempt == maxRetries - 1) rethrow;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
```

### Profile Caching

Local cache reduces API calls and improves cold start:

```dart
class AuthService {
  static const _kCachedProfileJson = 'cached_profile_json';
  
  Future<void> _cacheUserProfile(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedProfileJson, jsonEncode(user.toJson()));
  }
}
```

## Key Dependencies

```yaml
dependencies:
  supabase_flutter: ^2.8.0      # Supabase client
  flutter_bloc: ^8.1.6          # State management
  synchronized: ^3.1.0          # Thread-safe locking
  shared_preferences: ^2.3.4    # Local caching
  firebase_messaging: ^15.0.0   # Push notifications
  flutter_animate: ^4.5.2       # Animations
  google_fonts: ^6.2.1          # Typography
```

## Color Palette (Theme)

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0F` | Main background |
| Surface | `#15151A` | Cards, inputs |
| Primary Orange | `#E8956A` | Primary actions |
| Primary Coral | `#F0A878` | Gradients |
| Primary Teal | `#4ECDC4` | Secondary highlights |
| Text Primary | `#F8FAFC` | Main text |
| Text Secondary | `#94A3B8` | Subtitles |

## Development Workflow

1. Start Supabase locally: `supabase start`
2. Run app: `flutter run -d chrome --web-port=3000`
3. Make changes with hot reload
4. Run tests: `flutter test`
5. Format code: `dart format .`
6. Analyze: `flutter analyze`
7. Commit with clear messages

## Anti-Patterns to Avoid

- Don't use `dynamic` unless absolutely necessary
- Avoid `setState` in large widgets - use BLoC
- Don't hardcode strings - use localization constants
- Never commit API keys - use `.env` files
- Don't block UI with long operations - use async/await with loading states
- Don't forget RLS policies for new tables
- Don't ignore 429 errors - implement retry logic
- Don't use auth.users.id directly - lookup by email/phone first

## Resources

- Flutter docs: https://docs.flutter.dev
- Dart style guide: https://dart.dev/effective-dart
- Supabase docs: https://supabase.com/docs
- README.md: Detailed project documentation
