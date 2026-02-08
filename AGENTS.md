# AGENTS.md - Gym Buddy App

Guidelines for agentic coding agents working on the Gym Buddy App.

## Project Overview

A session-based gym buddy coordination app with passive GPS verification. Built with Flutter (frontend) and Supabase (backend). See `Project-Context.md` and `Phases.md` for full context.

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime)
- **Location**: Google Maps Platform
- **Notifications**: Firebase Cloud Messaging
- **Storage**: Cloudinary or AWS S3

## Build Commands

### Flutter

```bash
# Install dependencies
flutter pub get

# Run app (hot reload enabled)
flutter run

# Run on specific device
flutter run -d <device_id>

# Build for production
flutter build apk              # Android
flutter build ios              # iOS (requires macOS/Xcode)
flutter build web              # Web
flutter build ipa              # iOS App Store bundle

# Analyze code
flutter analyze

# Fix auto-fixable issues
flutter fix
```

### Testing

```bash
# Run all tests
flutter test

# Run single test file
flutter test test/fetch_album_test.dart

# Run specific test by name
flutter test --name "test_name"

# Run with coverage
flutter test --coverage
```

### Code Quality

```bash
# Format all Dart files
dart format .

# Check formatting (CI)
dart format --output=none --set-exit-if-changed .

# Analyze with custom rules
flutter analyze --fatal-infos --fatal-warnings
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

## Code Style Guidelines

### Dart/Flutter

**Naming Conventions:**
- Classes: `PascalCase` (e.g., `SessionManager`)
- Variables/functions: `lowerCamelCase` (e.g., `getUserSessions`)
- Constants: `lowerCamelCase` or `kPascalCase` (e.g., `apiUrl` or `kApiUrl`)
- Files: `snake_case.dart` (e.g., `session_service.dart`)
- Private members: `_leadingUnderscore`

**Imports - Order:**
```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:convert';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Third-party packages
import 'package:supabase_flutter/supabase_flutter.dart';

// 4. Project imports (relative)
import '../models/session.dart';
```

**Formatting:**
- Always run `dart format` before committing
- Line length: 80 characters (default)
- Use trailing commas for multi-line lists/parameters
- 2-space indentation

**Types:**
- Use `final` for variables that don't change
- Use `const` for compile-time constants
- Prefer explicit types over `var` for public APIs
- Use null safety properly - mark nullable types with `?`

**Error Handling:**
```dart
try {
  await api.createSession(data);
} on PostgrestException catch (e) {
  logger.e('Database error: ${e.message}');
  rethrow;
} catch (e, stackTrace) {
  logger.e('Unexpected error', error: e, stackTrace: stackTrace);
}
```

**Widget Structure:**
```dart
class SessionCard extends StatelessWidget {
  const SessionCard({required this.session, super.key});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(session.title),
      ),
    );
  }
}
```

**State Management:**
- Prefer `flutter_bloc` or `riverpod` for state management
- Keep widgets small and focused
- Separate business logic from UI

**Testing:**
```dart
group('SessionService', () {
  test('should create session with valid data', () async {
    final service = SessionService();
    final result = await service.createSession(testData);
    expect(result, isA<Session>());
  });
});
```

## Architecture Patterns

### Project Structure
```
lib/
├── main.dart
├── app.dart
├── config/              # App configuration
├── models/              # Data models
├── services/            # Business logic
├── repositories/        # Data access
├── blocs/               # State management
├── widgets/             # Reusable widgets
└── screens/             # UI screens
test/
├── unit/
├── widget/
└── integration/
```

### Key Principles
1. **Repository Pattern**: Abstract data sources (Supabase, cache)
2. **Dependency Injection**: Use `get_it` or `injectable`
3. **Error Boundaries**: Use `ErrorWidget` for UI errors
4. **Offline Support**: Cache critical data locally

## Environment Setup

```bash
# Install Flutter (use fvm for version management)
curl -fsSL https://fvm.app/install.sh | bash
fvm install stable
fvm use stable

# Install Supabase CLI
npm install -g supabase

# Setup environment variables
cp .env.example .env
```

## Development Workflow

1. Start Supabase locally: `supabase start`
2. Run app: `flutter run`
3. Make changes with hot reload
4. Run tests: `flutter test`
5. Format code: `dart format .`
6. Analyze: `flutter analyze`
7. Commit with clear messages

## Resources

- Flutter docs: https://docs.flutter.dev
- Dart style guide: https://dart.dev/effective-dart
- Supabase docs: https://supabase.com/docs
- Project context: See `Project-Context.md` and `Phases.md`

## Anti-Patterns to Avoid

- Don't use `dynamic` unless absolutely necessary
- Avoid `setState` in large widgets - use state management
- Don't hardcode strings - use localization
- Never commit API keys - use `.env` files
- Don't block UI with long operations - use async/await with loading states
