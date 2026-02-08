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

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Android Studio](https://developer.android.com/studio) (for Android development) or [Xcode](https://developer.apple.com/xcode/) (for iOS development)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional, for local development)
- A physical device or emulator/simulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd LiftCo
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup environment variables**
   
   Create a `.env` file in the project root:
   ```bash
   cp .env.example .env
   ```
   
   Add your Supabase credentials to `.env`:
   ```bash
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

4. **Verify installation**
   ```bash
   flutter doctor
   ```

---

## 🏃 Running the App

### Development Mode

1. **Check connected devices**
   ```bash
   flutter devices
   ```

2. **Run the app**
   ```bash
   flutter run
   ```
   
   Or specify a device:
   ```bash
   flutter run -d <device-id>
   ```

3. **Hot reload** - Press `r` in the terminal to reload changes
4. **Hot restart** - Press `R` to restart the app
5. **Quit** - Press `q` to quit

### Debug Mode with Logs

```bash
flutter run --debug --verbose
```

---

## 🧪 Testing

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/widget_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### Integration Testing

1. **Start the app in test mode**
   ```bash
   flutter run --target=test_driver/app.dart
   ```

2. **Run integration tests**
   ```bash
   flutter drive --target=test_driver/app.dart
   ```

---

## 📦 Building & Compiling

### Android APK

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

**App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

Output locations:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### iOS

**Build for iOS (macOS only):**
```bash
flutter build ios --release
```

**Build IPA for distribution:**
```bash
flutter build ipa --release
```

Output location:
- IPA: `build/ios/ipa/LiftCo.ipa`

### Web

```bash
flutter build web --release
```

Output location:
- Web: `build/web/`

---

## 🎨 App Structure

```
lib/
├── blocs/              # State management (BLoC pattern)
│   └── auth_bloc.dart  # Authentication logic
├── config/             # App configuration
│   └── theme.dart      # App theme and colors
├── models/             # Data models
│   └── user.dart       # User model
├── screens/            # UI screens
│   ├── login_screen.dart
│   ├── profile_setup_screen.dart
│   └── home_screen.dart
├── services/           # Business logic
│   └── auth_service.dart
└── main.dart           # App entry point
```

---

## 🔐 Authentication Flow

1. **Login Screen** - Choose between Email OTP, Phone OTP, Google, or Apple
2. **OTP Verification** - Enter 6-digit code (email users only)
3. **Profile Setup** - Complete your profile with visual cards:
   - Basic info (name, age, gender)
   - Experience level (Beginner/Intermediate/Advanced)
   - Preferred workout time (visual time cards)
   - Additional preferences (optional)
4. **Home Screen** - Start finding workout buddies!

---

## 🛠️ Development Commands

```bash
# Check code health
flutter analyze

# Format all Dart files
dart format .

# Check for outdated packages
flutter pub outdated

# Upgrade packages
flutter pub upgrade

# Clean build artifacts
flutter clean

# Get dependencies after clean
flutter pub get
```

---

## 📱 Supported Platforms

| Platform | Minimum Version | Status |
|----------|----------------|---------|
| Android | API 21 (Android 5.0) | ✅ Supported |
| iOS | iOS 12.0 | ✅ Supported |
| Web | Modern browsers | ✅ Supported |

---

## 🌟 Code Quality

This project follows:
- **Flutter Best Practices** - Official Flutter style guide
- **Effective Dart** - Dart language guidelines
- **BLoC Pattern** - Predictable state management
- **Clean Architecture** - Separation of concerns

### Pre-commit Checks

Before committing, run:
```bash
flutter analyze && dart format --output=none --set-exit-if-changed .
```

---

## 🔧 Troubleshooting

### Common Issues

**1. App not installing on Android**
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

**2. iOS build failures**
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter build ios
```

**3. Supabase connection errors**
- Verify `.env` file exists and contains valid credentials
- Check internet connection
- Ensure Supabase project is active

**4. Flutter version issues**
```bash
# Check Flutter version
flutter --version

# Upgrade Flutter
flutter upgrade
```

---

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Supabase Documentation](https://supabase.com/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [BLoC Pattern](https://bloclibrary.dev)

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License.

---

## 🆘 Support

For issues and questions:
- Check the [troubleshooting](#-troubleshooting) section
- Review existing issues on GitHub
- Create a new issue with detailed information

---

**Built with ❤️ for fitness enthusiasts**
