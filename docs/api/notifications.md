# Notification System Documentation

## Overview

The Gym Buddy notification system uses Firebase Cloud Messaging (FCM) to send push notifications to users' devices when important events occur, such as when a new member joins their workout session.

## Architecture

```
User Joins Session
       ↓
sessions-join Edge Function
       ↓
Fetch existing members
       ↓
Trigger notifications-send
       ↓
Fetch FCM tokens from user_devices
       ↓
Send FCM messages via HTTP v1 API
       ↓
Handle responses & cleanup invalid tokens
```

## Features

### ✅ Implemented

- **Automatic Notifications** - Sent when users join sessions
- **Smart Targeting** - Only notifies existing members (not the joiner)
- **Invalid Token Cleanup** - Auto-removes uninstalled app tokens
- **Secure** - RLS policies protect device tokens
- **Batch Processing** - Efficiently handles multiple recipients
- **Rich Payload** - Includes session details for deep linking

### 📱 Notification Example

```json
{
  "notification": {
    "title": "Squad Update! 💪",
    "body": "John joined your Morning Push session on Feb 10, 10:00 AM!"
  },
  "data": {
    "session_id": "123",
    "type": "member_joined",
    "new_member_name": "John",
    "session_title": "Morning Push"
  }
}
```

## Database Schema

### user_devices Table

```sql
CREATE TABLE user_devices (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type VARCHAR(20),      -- 'Android', 'iOS', 'Web'
    device_name VARCHAR(100),     -- e.g., 'iPhone 13'
    is_active BOOLEAN DEFAULT true,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_user_fcm_token UNIQUE (user_id, fcm_token)
);

-- Indexes for performance
CREATE INDEX idx_user_devices_user_id ON user_devices (user_id);
CREATE INDEX idx_user_devices_fcm_token ON user_devices (fcm_token);
CREATE INDEX idx_user_devices_active ON user_devices (user_id, is_active) WHERE is_active = true;
```

### RLS Policies

```sql
-- Users can only access their own devices
CREATE POLICY "Users can view own devices" ON user_devices
  FOR SELECT
  USING (user_id = (SELECT id FROM users WHERE email = auth.email()));

CREATE POLICY "Users can insert own devices" ON user_devices
  FOR INSERT
  WITH CHECK (user_id = (SELECT id FROM users WHERE email = auth.email()));

CREATE POLICY "Users can update own devices" ON user_devices
  FOR UPDATE
  USING (user_id = (SELECT id FROM users WHERE email = auth.email()));

CREATE POLICY "Users can delete own devices" ON user_devices
  FOR DELETE
  USING (user_id = (SELECT id FROM users WHERE email = auth.email()));

-- Service role has full access for backend logic
CREATE POLICY "Service role has full access" ON user_devices
  FOR ALL
  USING (auth.role() = 'service_role');
```

## API Endpoints

### 1. Register Device

Register a device to receive push notifications.

**Endpoint:** `POST /devices-register`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "fcm_token": "bk3RNwTe3H0:CI2k_HHwgIpoDKCIZvvDMExUdFQ3P1...",
  "device_type": "iOS",
  "device_name": "iPhone 13 Pro"
}
```

**Response (201):**
```json
{
  "message": "Device registered successfully",
  "device": {
    "id": 1,
    "user_id": 1,
    "fcm_token": "bk3RNwTe3H0:CI2k_HHwgIpoDKCIZvvDMExUdFQ3P1...",
    "device_type": "iOS",
    "device_name": "iPhone 13 Pro",
    "is_active": true,
    "last_seen_at": "2026-02-08T12:00:00.000Z",
    "created_at": "2026-02-08T12:00:00.000Z"
  }
}
```

**cURL Example:**
```bash
# Correct URL format: https://<project>.supabase.co/functions/v1/<function>
curl -X POST "$BASE_URL/devices-register" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fcm_token": "your_fcm_token_here",
    "device_type": "iOS",
    "device_name": "iPhone 13"
  }'

# Note: $BASE_URL should be: https://bpfptwqysbouppknzaqk.supabase.co/functions/v1
```

**Getting a JWT Access Token:**

1. **Request OTP:**
```bash
curl -X POST "$BASE_URL/auth-email-request-otp" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

2. **Verify OTP:** (Check email for code or use test OTP `123456`)
```bash
curl -X POST "$BASE_URL/auth-email-verify-otp" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "otp": "123456"}'
```

3. **Use the `access_token` from response:**
```json
{
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",  // <-- Use this
    "refresh_token": "...",
    "expires_at": 1234567890
  }
}
```

---

### 2. Remove Device

Remove a device from receiving notifications.

**Endpoint:** `DELETE /devices-remove`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "fcm_token": "bk3RNwTe3H0:CI2k_HHwgIpoDKCIZvvDMExUdFQ3P1..."
}
```

**Response (200):**
```json
{
  "message": "Device removed successfully"
}
```

**cURL Example:**
```bash
curl -X DELETE "$BASE_URL/devices-remove" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fcm_token": "your_fcm_token_here"}'
```

---

### 3. Send Notification (Internal)

Send notifications to users (called internally by other functions).

**Endpoint:** `POST /notifications-send`

**Headers:**
```
Authorization: Bearer <service_role_key>
Content-Type: application/json
```

**Request Body:**
```json
{
  "user_ids": [1, 2, 3],
  "title": "Squad Update! 💪",
  "body": "John joined your Morning Push session!",
  "data": {
    "session_id": "123",
    "type": "member_joined"
  }
}
```

**Response (200):**
```json
{
  "message": "Notifications processed",
  "sent": 3,
  "failed": 0,
  "invalid_tokens_removed": 1,
  "results": [
    {"user_id": 1, "status": "sent"},
    {"user_id": 2, "status": "sent"},
    {"user_id": 3, "status": "failed", "error": "INVALID_TOKEN"}
  ]
}
```

**Note:** This endpoint is for internal use only. Regular users cannot call it directly.

---

## Flutter Integration

### Setup

1. **Add Firebase to your Flutter app:**

```bash
# Install Firebase CLI
curl -sL https://firebase.tools | bash

# Login
firebase login

# Configure FlutterFire
flutter pub add firebase_core firebase_messaging
dart pub global activate flutterfire_cli
flutterfire configure
```

2. **Initialize Firebase in main.dart:**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Request permission
  await FirebaseMessaging.instance.requestPermission();
  
  runApp(MyApp());
}
```

3. **Register device after login:**

```dart
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Future<void> registerDevice() async {
    // Get FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;
    
    // Get device info
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    final deviceType = Platform.isAndroid ? 'Android' : 'iOS';
    final deviceName = deviceInfo is IosDeviceInfo 
        ? deviceInfo.name 
        : deviceInfo is AndroidDeviceInfo 
            ? deviceInfo.model 
            : 'Unknown';
    
    // Register with backend
    await _supabase.functions.invoke(
      'devices-register',
      body: {
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
      },
    );
    
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // Remove old token
      await _supabase.functions.invoke(
        'devices-remove',
        body: {'fcm_token': fcmToken},
      );
      
      // Register new token
      await _supabase.functions.invoke(
        'devices-register',
        body: {
          'fcm_token': newToken,
          'device_type': deviceType,
          'device_name': deviceName,
        },
      );
    });
  }
  
  Future<void> logout() async {
    // Remove device
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _supabase.functions.invoke(
        'devices-remove',
        body: {'fcm_token': fcmToken},
      );
    }
    
    // Sign out
    await _supabase.auth.signOut();
  }
}
```

4. **Handle foreground messages:**

```dart
class NotificationService {
  static void initialize() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        
        // Show local notification
        showLocalNotification(
          title: message.notification!.title!,
          body: message.notification!.body!,
          payload: message.data,
        );
      }
    });
    
    // Background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print('Handling a background message: ${message.messageId}');
  }
}
```

5. **Handle notification taps:**

```dart
// When user taps notification
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final sessionId = message.data['session_id'];
  if (sessionId != null) {
    // Navigate to session detail
    Navigator.pushNamed(context, '/session', arguments: sessionId);
  }
});
```

---

## Triggered Notifications

### Session Join

**When:** A user joins a session

**Who receives:** All existing members (not the joiner)

**Payload:**
```json
{
  "notification": {
    "title": "Squad Update! 💪",
    "body": "{user_name} joined your {session_title} session on {date_time}!"
  },
  "data": {
    "session_id": "123",
    "type": "member_joined",
    "new_member_name": "John",
    "session_title": "Morning Push"
  }
}
```

---

## Error Handling

### Invalid Token Detection

When FCM returns an error indicating the token is invalid (user uninstalled app):

```typescript
// Error codes that indicate invalid token
const INVALID_TOKEN_ERRORS = [
  'UNREGISTERED',
  'NOT_FOUND',
  'InvalidRegistration'
];

if (INVALID_TOKEN_ERRORS.includes(errorCode)) {
  // Delete from database
  await supabase
    .from('user_devices')
    .delete()
    .eq('fcm_token', token);
}
```

### Retry Logic

For transient failures, implement exponential backoff:

```typescript
const sendWithRetry = async (message: FCMMessage, retries = 3) => {
  for (let i = 0; i < retries; i++) {
    try {
      return await sendFCMMessage(message);
    } catch (error) {
      if (i === retries - 1) throw error;
      await sleep(Math.pow(2, i) * 1000); // Exponential backoff
    }
  }
};
```

---

## Testing

### Test Device Registration

```bash
# 1. Register device
curl -X POST "$BASE_URL/devices-register" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fcm_token": "test_token_123",
    "device_type": "iOS",
    "device_name": "Test iPhone"
  }'

# 2. Verify in database
# SELECT * FROM user_devices;
```

### Test Notification Sending

```bash
# Send test notification
curl -X POST "$BASE_URL/notifications-send" \
  -H "Authorization: Bearer SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_ids": [1],
    "title": "Test",
    "body": "Test notification",
    "data": {"test": "true"}
  }'
```

### Test via Flutter App

```dart
// Get FCM token
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Send test notification using Firebase Console
// Or use the backend API
```

---

## Security Considerations

### 1. Token Storage

- ✅ FCM tokens stored in PostgreSQL with RLS
- ✅ Users can only access their own tokens
- ✅ Service role for backend operations
- ❌ Never expose tokens in client-side code

### 2. API Security

- ✅ `notifications-send` requires service role key
- ✅ Regular users cannot send arbitrary notifications
- ✅ Rate limiting recommended for production

### 3. Data Privacy

- ✅ Tokens automatically deleted when users uninstall
- ✅ No PII stored with tokens
- ✅ GDPR compliant (right to be forgotten)

---

## Monitoring

### Function Logs

```bash
# View notification function logs
supabase functions logs notifications-send

# View session join logs
supabase functions logs sessions-join
```

### Key Metrics

- **Delivery Rate** - Successfully sent / Total attempted
- **Invalid Token Rate** - Invalid tokens / Total tokens
- **Latency** - Time from join to notification delivery

### Database Queries

```sql
-- Count active devices per user
SELECT user_id, COUNT(*) as device_count
FROM user_devices
WHERE is_active = true
GROUP BY user_id;

-- Find stale devices (not seen in 30 days)
SELECT *
FROM user_devices
WHERE last_seen_at < NOW() - INTERVAL '30 days';

-- Most popular device types
SELECT device_type, COUNT(*) as count
FROM user_devices
GROUP BY device_type
ORDER BY count DESC;
```

---

## Troubleshooting

### Issue: Notifications not received

**Check:**
1. Device registered successfully in `user_devices`
2. FCM token is valid (not expired)
3. User granted notification permissions
4. Device is online

**Debug:**
```bash
# Check if device exists
SELECT * FROM user_devices WHERE user_id = 1;

# Test notification
supabase functions invoke notifications-send --data '{
  "user_ids": [1],
  "title": "Test",
  "body": "Test"
}'
```

### Issue: Invalid token not deleted

**Check:**
1. Service role key is correct
2. Error handling in `notifications-send` function
3. Token format matches expected pattern

### Issue: High failure rate

**Possible causes:**
- Many users uninstalled app
- FCM service issues
- Rate limiting

**Solution:**
- Implement batch processing
- Add retry logic
- Monitor FCM status page

---

## Future Enhancements

### Planned Features

- [ ] **Session Reminders** - Notify 1 hour before session starts
- [ ] **Host Notifications** - Notify when someone joins their session
- [ ] **Cancellation Alerts** - Notify when session is cancelled
- [ ] **In-App Notifications** - Store notification history
- [ ] **Rich Media** - Images in notifications
- [ ] **Notification Preferences** - Let users customize notification settings

### Advanced Features

- [ ] **Topic-based** - Subscribe to gym-specific topics
- [ ] **Scheduled** - Schedule future notifications
- [ ] **Analytics** - Track open rates and engagement
- [ ] **A/B Testing** - Test different notification formats

---

## Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
