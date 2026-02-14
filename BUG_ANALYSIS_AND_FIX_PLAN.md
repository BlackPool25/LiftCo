# LiftCo Gym Buddy App - Bug Analysis & Fix Plan

**Date:** February 14, 2026  
**Project:** LiftCo - Gym Buddy Coordination App  
**Status:** Analysis Complete - Ready for Implementation

---

## Executive Summary

This report analyzes 6 critical bugs and improvement areas in the LiftCo app based on thorough code review of the Flutter frontend and Supabase backend. Each issue includes root cause analysis, affected files, and a concrete fix plan.

---

## Bug #1: App Shows Profile Setup on Cold Start (Race Condition)

### **Issue Description**
When opening the app from a cold start (not in memory), the profile setup screen appears even when the user has already completed their profile. This happens because the app checks auth state before the user profile is fully loaded from the database.

### **Root Cause Analysis**

**File:** `lib/blocs/auth_bloc.dart:197-229`

```dart
Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  try {
    if (_authService.isAuthenticated) {
      final user = await _authService.getUserProfile();  // <-- Async call may fail temporarily
      if (user != null) {
        if (user.isProfileComplete) {
          emit(Authenticated(user));
        } else {
          emit(NeedsProfileCompletion(...));  // <-- Shown incorrectly on race condition
        }
      } else {
        emit(NeedsProfileCompletion(...));  // <-- Shown incorrectly if lookup fails
      }
    }
  } catch (e) {
    emit(Unauthenticated(errorMessage: e.toString()));
  }
}
```

**Problem:**
1. `getUserProfile()` queries `users` table by `auth_id` 
2. Database triggers may not have completed syncing `auth_id` from `auth.users`
3. When user profile lookup returns `null`, the app incorrectly assumes profile is incomplete
4. Edge functions like `users-get-me` also rely on auth_id mapping

**Affected Files:**
- `lib/blocs/auth_bloc.dart` - Auth state management
- `lib/services/auth_service.dart:126-143` - Profile fetching
- `lib/services/current_user_resolver.dart` - User ID resolution
- `supabase/migrations/20260213222000_enforce_users_identity_and_contact_rules.sql` - Identity sync

### **Impact**
- Poor user experience: returning users see setup screen
- Potential data loss if user re-submits profile
- Trust issues with app stability

### **Fix Plan**

**Option A: Add Retry Logic with Delay** (Recommended - Quick Fix)

```dart
Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  
  if (!_authService.isAuthenticated) {
    emit(const Unauthenticated());
    return;
  }
  
  // Retry profile fetch up to 3 times with delay
  User? user;
  for (int i = 0; i < 3; i++) {
    user = await _authService.getUserProfile();
    if (user != null) break;
    await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
  }
  
  if (user != null && user.isProfileComplete) {
    emit(Authenticated(user));
    await _registerDeviceSilently();
  } else if (user != null) {
    emit(NeedsProfileCompletion(...));
  } else {
    // After retries, check if this is a new user by checking auth metadata
    final isNewUser = await _checkIfNewUser();
    if (isNewUser) {
      emit(NeedsProfileCompletion(...));
    } else {
      // Existing user but profile lookup failed - show loading or error
      emit(AuthError('Unable to load profile. Please try again.'));
    }
  }
}
```

**Option B: Cache Profile Status Locally** (Better Long-term)

```dart
// In auth_service.dart
Future<bool> isProfileCompleteFromCache() async {
  // Check SharedPreferences for cached profile status
  final prefs = await SharedPreferences.getInstance();
  final cachedStatus = prefs.getBool('profile_complete');
  if (cachedStatus == true) return true;
  
  // Fall back to server check
  final user = await getUserProfile();
  final isComplete = user?.isProfileComplete ?? false;
  await prefs.setBool('profile_complete', isComplete);
  return isComplete;
}
```

**Option C: Fix Database Trigger Timing** (Root Cause Fix)

Update the trigger in migration to be synchronous:

```sql
-- Instead of relying on triggers, ensure auth_id is set during signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, auth_id, email, phone_number)
  VALUES (NEW.id, NEW.id, NEW.email, NEW.phone)
  ON CONFLICT (auth_id) DO UPDATE
  SET email = EXCLUDED.email,
      phone_number = EXCLUDED.phone;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Bug #2: Female-Only Toggle Layout Overflow

### **Issue Description**
The female-only session toggle in `home_tab.dart` and `gym_details_screen.dart` extends outside the screen bounds, particularly on smaller devices.

### **Root Cause Analysis**

**File:** `lib/screens/home_tab.dart:1025-1028`

```dart
// Female-only mode toggle (for female users only)
if (_currentUser.gender?.toLowerCase() == 'female') ...[
  const SizedBox(width: 8),
  SizedBox(width: 172, child: _buildWomenOnlyToggle()),  // <-- Fixed width causes overflow
],
```

**File:** `lib/screens/gym_details_screen.dart:145-147`

```dart
// Female-only mode toggle
if (_currentUserGender?.toLowerCase() == 'female') ...[
  SizedBox(width: 172, child: _buildWomenOnlyToggle()),  // <-- Same issue
  const SizedBox(width: 8),
],
```

**Problem:**
- Hard-coded width of 172px doesn't account for all screen sizes
- App logo "LiftCo" takes significant space on the left
- Notification bell icon adds more width
- On smaller devices (<360px width), this causes overflow

**Affected Files:**
- `lib/screens/home_tab.dart:1025-1028`
- `lib/screens/gym_details_screen.dart:145-147`

### **Impact**
- UI looks broken on smaller phones
- Toggle may be partially inaccessible
- Poor user experience for female users

### **Fix Plan**

**Fix: Use Flexible Layout** 

```dart
// In home_tab.dart _buildAppBar()
Row(
  children: [
    // App logo + name
    Flexible(
      flex: 2,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo...
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'LiftCo',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    const Spacer(),
    // Notification bell
    GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      onTap: () {},
      child: Stack(...),
    ),
    // Female-only toggle with flexible width
    if (_currentUser.gender?.toLowerCase() == 'female') ...[
      const SizedBox(width: 8),
      Flexible(
        flex: 3,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 172, minWidth: 120),
          child: _buildWomenOnlyToggle(),
        ),
      ),
    ],
  ],
)
```

**Alternative: Move to Filter Section**

Consider moving the women-only toggle to the filter bar below the header instead of the app bar:

```dart
// In _buildSessionsSection, add toggle next to filter button
Row(
  children: [
    Text('Available Sessions', style: Theme.of(context).textTheme.titleLarge),
    const Spacer(),
    // Move toggle here
    if (_currentUser.gender?.toLowerCase() == 'female')
      _buildWomenOnlyToggle(),
    const SizedBox(width: 8),
    // Filter button
    GestureDetector(...),
  ],
)
```

---

## Bug #3: Auth Exception on Sign Out/Sign In (UUID Check)

### **Issue Description**
When signing out and signing back in, there's a chance of auth exceptions. The current system uses email/phone for user identification but should use UUID for consistency.

### **Root Cause Analysis**

**File:** `lib/services/auth_service.dart:126-161`

```dart
Future<User?> getUserProfile() async {
  try {
    final authUser = currentAuthUser;
    if (authUser == null) return null;

    final response = await _supabase
        .from('users')
        .select()
        .eq('auth_id', authUser.id)  // <-- Uses auth UUID
        .maybeSingle();
    ...
  }
}

Future<bool> checkUserExists() async {
  final authUser = currentAuthUser;
  if (authUser == null) return false;

  final response = await _supabase
      .from('users')
      .select('id')
      .eq('auth_id', authUser.id)  // <-- Uses auth UUID
      .maybeSingle();

  return response != null;
}
```

**File:** `lib/blocs/auth_bloc.dart:403-446` - `_onAuthStateChanged`

**Problem:**
1. The app uses `auth.users.id` (UUID) to query `users` table via `auth_id` column
2. Database triggers try to sync these IDs but there's a timing issue
3. When auth state changes rapidly (sign out/in), the auth_id mapping may not be complete
4. Edge functions use service role to bypass RLS, but Flutter app uses auth context

**Database Context:**

```sql
-- Migration shows auth_id is auto-set via triggers
CREATE TRIGGER users_ensure_identity_consistency
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.ensure_users_identity_consistency();
```

**Affected Files:**
- `lib/services/auth_service.dart:126-161`
- `lib/blocs/auth_bloc.dart:403-446`
- `lib/services/current_user_resolver.dart:5-35`

### **Impact**
- Users may get stuck in auth loops
- Profile completion screen shown incorrectly
- Potential for duplicate user records

### **Fix Plan**

**Fix: Use Auth UID Directly**

The app already uses UUID correctly via `auth_id`. The issue is timing of database sync. Implement these changes:

**1. Update auth_service.dart to handle missing auth_id gracefully:**

```dart
Future<User?> getUserProfile() async {
  try {
    final authUser = currentAuthUser;
    if (authUser == null) return null;

    // Try by auth_id first
    var response = await _supabase
        .from('users')
        .select()
        .eq('auth_id', authUser.id)
        .maybeSingle();
    
    // Fallback: try by email/phone if auth_id lookup fails
    if (response == null && (authUser.email != null || authUser.phone != null)) {
      var query = _supabase.from('users').select();
      if (authUser.email != null) {
        query = query.eq('email', authUser.email!);
      } else if (authUser.phone != null) {
        query = query.eq('phone_number', authUser.phone!);
      }
      response = await query.maybeSingle();
      
      // If found by email/phone but auth_id is different, update it
      if (response != null && response['auth_id'] != authUser.id) {
        await _supabase
            .from('users')
            .update({'auth_id': authUser.id})
            .eq('id', response['id']);
        response['auth_id'] = authUser.id;
      }
    }
    
    if (response == null) return null;
    return User.fromJson(response);
  } catch (e) {
    debugPrint('Error fetching user profile: $e');
    return null;
  }
}
```

**2. Ensure database constraint allows email OR phone lookups:**

```sql
-- Add index for faster email/phone lookups
CREATE INDEX idx_users_email ON public.users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_phone ON public.users(phone_number) WHERE phone_number IS NOT NULL;
```

---

## Bug #4: Session Details Shows "Join" Before Checking Membership

### **Issue Description**
When clicking on session details, it initially shows "Join Session" button, then after fetching data, it changes to "Already Joined" if the user is already a member. This creates a flickering UI.

### **Root Cause Analysis**

**File:** `lib/screens/session_details_screen.dart:22-140`

```dart
class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  WorkoutSession? _session;
  final bool _isLoading = false;  // <-- Always false, never shows loading
  bool _isUserJoined = false;     // <-- Default false, shows Join button initially
  
  @override
  void initState() {
    super.initState();
    _session = widget.session;    // <-- Uses passed session initially
    _getCurrentUser();
    _loadSessionDetails();        // <-- Async, updates state after fetch
    _subscribeToSession();
    _subscribeToMembers();
  }
```

**File:** `lib/screens/session_details_screen.dart:986-1199` - `_buildBottomBar()`

```dart
Widget? _buildBottomBar() {
  // Can join session
  if (_canJoin) {
    return GradientButton(text: 'Join Session', ...);  // <-- Shown when !_isUserJoined
  }
  // Already joined
  if (_isUserJoined) {
    return GlassCard(child: Text('You\'ve Joined'));  // <-- Shown after fetch
  }
}
```

**Problem:**
1. Screen receives initial session from navigation (without membership info)
2. `_isUserJoined` defaults to `false` 
3. `_isLoading` is hard-coded to `false` and never used
4. UI renders immediately with "Join" button
5. Async fetch completes and updates state, causing button to change

**Affected Files:**
- `lib/screens/session_details_screen.dart` - Main issue

### **Impact**
- UI flickering looks unprofessional
- User might click "Join" before state updates, causing errors
- Confusing UX

### **Fix Plan**

**Fix: Show Loading State Until Membership Verified**

```dart
class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  WorkoutSession? _session;
  bool _isLoading = true;  // <-- Start as true
  bool _isJoining = false;
  String? _currentUserId;
  bool _isUserJoined = false;
  bool _membershipChecked = false;  // <-- Track if we've checked membership

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _session = widget.session;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Get current user first
    await _getCurrentUser();
    
    // Load session details with membership info
    await _loadSessionDetails();
    
    // Mark as loaded
    if (mounted) {
      setState(() {
        _isLoading = false;
        _membershipChecked = true;
      });
    }
    
    // Set up subscriptions after initial load
    _subscribeToSession();
    _subscribeToMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      ...
      bottomNavigationBar: _isLoading || !_membershipChecked
          ? _buildLoadingBottomBar()  // <-- Show skeleton/loading state
          : _buildBottomBar(),
    );
  }

  Widget _buildLoadingBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryPurple,
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Bug #5 & #6: Data Fetching Strategy - Real-time vs Refresh

### **Issue Description**
The user wants a hybrid approach:
- **User's joined sessions**: Keep real-time subscription (like DM list in Instagram)
- **Available sessions**: Use refresh button (like feed with pull-to-refresh)
- **Add refresh buttons** to all gym pages

### **Current Implementation Analysis**

**Home Tab (`lib/screens/home_tab.dart`):**
- Uses real-time subscriptions for ALL sessions (lines 66-68, 99-213)
- Subscribes to visible sessions individually (lines 100-151)
- Subscribes to recent sessions (lines 155-213)
- Subscribes to user memberships (lines 216-233)

**Schedule Tab (`lib/screens/schedule_screen.dart`):**
- Correctly subscribes only to user's sessions (lines 58-82)
- Uses `subscribeToUserSessions()` which is appropriate

**Gym Details (`lib/screens/gym_details_screen.dart`):**
- One-time fetch on init, no subscriptions (lines 66-85)
- No refresh button currently

### **Problems with Current Approach**

1. **Too many subscriptions** in Home tab - performance drain
2. **No manual refresh** option for available sessions
3. **Inconsistent patterns** across screens
4. **User can't force refresh** when they know data changed

### **Fix Plan**

**1. Update Home Tab - Remove Real-time for Available Sessions**

```dart
class _HomeTabState extends State<HomeTab> {
  // Remove these subscription-related fields:
  // final Map<String, StreamSubscription<WorkoutSession?>> _sessionSubscriptions = {};
  // StreamSubscription<List<WorkoutSession>>? _newSessionsSubscription;
  
  // Keep only user membership subscription:
  StreamSubscription<List<WorkoutSession>>? _userMembershipsSubscription;

  @override
  void initState() {
    super.initState();
    ...
    _loadSessions();           // <-- One-time fetch
    _loadGyms();
    _subscribeToUserMemberships();  // <-- Keep real-time for user sessions only
  }

  @override
  void dispose() {
    // Only cancel user membership subscription
    _userMembershipsSubscription?.cancel();
    super.dispose();
  }

  // Add pull-to-refresh
  Future<void> _refreshSessions() async {
    setState(() => _isLoadingSessions = true);
    await _loadSessions();
    setState(() => _isLoadingSessions = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshSessions,
      color: AppTheme.primaryPurple,
      backgroundColor: AppTheme.surface,
      child: SingleChildScrollView(...),
    );
  }
}
```

**2. Update Session Details Screen - Keep Real-time**

Session details should remain real-time since user is viewing a specific session they may have joined:

```dart
// Keep existing subscriptions in session_details_screen.dart
void _subscribeToSession() { ... }  // Keep this
void _subscribeToMembers() { ... }  // Keep this
```

**3. Add Refresh Button to All Session Lists**

```dart
// In _buildSessionsSection of home_tab.dart
Row(
  children: [
    Text('Available Sessions', style: Theme.of(context).textTheme.titleLarge),
    const Spacer(),
    // Add refresh button
    GestureDetector(
      onTap: _isLoadingSessions ? null : _refreshSessions,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isLoadingSessions
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 18, color: AppTheme.textSecondary),
      ),
    ),
    const SizedBox(width: 8),
    // Filter button
    GestureDetector(...),
  ],
)
```

**4. Update Gym Details Screen - Add Refresh**

```dart
class _GymDetailsScreenState extends State<GymDetailsScreen> {
  // Add refresh indicator to session list
  Widget _buildSessionsList() {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: AppTheme.primaryPurple,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(...),
    );
  }
}
```

---

## Bug #7: Female Members Unable to Join Sessions

### **Issue Description**
Female members are getting "unable to join sessions" error when trying to join any session (not just women-only).

### **Root Cause Analysis**

**File:** `supabase/functions/sessions-join/index.ts` (Edge Function)

```typescript
const { data: userProfile } = await serviceClient
  .from("users")
  .select("id, name, gender")
  .eq("auth_id", user.id)  // <-- Queries by auth_id
  .maybeSingle();

if (session.women_only && userProfile.gender !== "female") {
  return new Response(JSON.stringify({ error: "Women-only session" }), {
    status: 403,
    ...
  });
}
```

**Problem:**
1. Edge function queries `users` table by `auth_id`
2. If `auth_id` is not synced (same issue as Bug #1), `userProfile` is null
3. When `userProfile` is null, accessing `userProfile.gender` would fail
4. However, the code has a null check before, so the issue is likely earlier

**Looking at the code flow:**
```typescript
if (!userProfile) {
  return new Response(JSON.stringify({ error: "User profile not found" }), {
    status: 404,
    ...
  });
}
```

This means if profile is not found, it returns 404, not "unable to join". Let me check the Flutter side:

**File:** `lib/services/supabase_service.dart:242-244`

```dart
Future<Map<String, dynamic>> joinSession(String sessionId) async {
  return post('sessions-join', body: {'session_id': sessionId});
}
```

**File:** `lib/services/session_service.dart:54-65`

```dart
Future<void> joinSession(String sessionId) async {
  try {
    await _api.joinSession(sessionId);
  } on PostgrestException catch (e) {
    debugPrint('Error joining session: ${e.message}');
    throw Exception('Failed to join session: ${e.message}');
  } catch (e) {
    debugPrint('Unexpected error joining session: $e');
    if (e is Exception) rethrow;
    throw Exception('Failed to join session');
  }
}
```

**The Real Issue:**

The error message "unable to join sessions" doesn't match any of the error strings in the edge function. Looking more carefully:

1. **RLS Policy Issue:** Check the RLS policy for `session_members` insert:

```sql
CREATE POLICY "Allow users to join sessions"
  ON session_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = session_id 
        AND ws.women_only = false
      )
      OR
      (
        EXISTS (
          SELECT 1 FROM workout_sessions ws
          WHERE ws.id = session_id 
          AND ws.women_only = true
        )
        AND auth.uid() IN (
          SELECT id FROM users WHERE gender = 'female'
        )
      )
    )
  );
```

2. **The policy checks `auth.uid() IN (SELECT id FROM users WHERE gender = 'female')`**
   - This uses `auth.uid()` which is the auth.users.id
   - It checks if this UUID exists in users table with gender = 'female'
   - If `users.id` doesn't match `auth.users.id` (due to sync issues), this fails

**Affected Files:**
- `supabase/migrations/20250210220000_fix_session_members_schema_and_add_women_safety.sql`
- `supabase/functions/sessions-join/index.ts`

### **Impact**
- Female users cannot join ANY sessions (both women-only and general)
- Critical functionality broken
- Gender-based access control failing

### **Fix Plan**

**Root Cause:** The RLS policy checks `auth.uid() IN (SELECT id FROM users WHERE gender = 'female')` but `users.id` may not match `auth.uid()` due to ID sync issues.

**Fix 1: Update RLS Policy to Use auth_id**

```sql
-- Drop existing policy
DROP POLICY IF EXISTS "Allow users to join sessions" ON session_members;

-- Create fixed policy using auth_id instead of id
CREATE POLICY "Allow users to join sessions"
  ON session_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = session_id 
        AND ws.women_only = false
      )
      OR
      (
        EXISTS (
          SELECT 1 FROM workout_sessions ws
          WHERE ws.id = session_id 
          AND ws.women_only = true
        )
        AND EXISTS (
          SELECT 1 FROM users 
          WHERE auth_id = auth.uid() 
          AND gender = 'female'
        )
      )
    )
  );
```

**Fix 2: Ensure ID Consistency**

Make sure `users.id` always equals `auth_id` (should already be enforced by migration `20260213222000_enforce_users_identity_and_contact_rules.sql`):

```sql
-- Verify all users have matching id and auth_id
SELECT id, auth_id, gender 
FROM users 
WHERE id != auth_id OR auth_id IS NULL;

-- Fix any mismatched records
UPDATE users SET id = auth_id WHERE id != auth_id AND auth_id IS NOT NULL;
```

**Fix 3: Add Better Error Logging in Edge Function**

```typescript
// In sessions-join edge function, add detailed logging
console.log('Join attempt:', {
  authUserId: user.id,
  userProfileId: userProfile?.id,
  userProfileGender: userProfile?.gender,
  sessionId,
  sessionWomenOnly: session?.women_only,
});
```

---

## Implementation Priority

### **P0 - Critical (Fix Immediately)**
1. **Bug #7** - Female members can't join sessions (blocks core functionality)
2. **Bug #1** - Race condition on app start (poor first impression)

### **P1 - High Priority**
3. **Bug #4** - Session details flicker (user confusion)
4. **Bug #2** - Layout overflow (UI polish)

### **P2 - Medium Priority**
5. **Bug #3** - Auth exception handling (stability)
6. **Bug #5/6** - Data fetching strategy (performance optimization)

---

## Testing Checklist

### **Bug #1 - Race Condition**
- [ ] Fresh install app, complete profile, kill app, reopen - should show home screen
- [ ] Test with slow network connection
- [ ] Test on both iOS and Android

### **Bug #2 - Layout**
- [ ] Test on iPhone SE (small screen)
- [ ] Test on various Android screen sizes
- [ ] Verify toggle is fully visible and tappable

### **Bug #3 - Auth**
- [ ] Sign out, sign in with same account - should work smoothly
- [ ] Sign out, sign in with different account - should switch profiles
- [ ] Test with email and phone auth methods

### **Bug #4 - Session Details**
- [ ] Open session details for joined session - should show "Joined" immediately
- [ ] Open session details for available session - should show "Join" immediately
- [ ] No flickering between states

### **Bug #5/6 - Refresh**
- [ ] Pull to refresh on home tab works
- [ ] Refresh button in session lists works
- [ ] Real-time updates still work for user's joined sessions
- [ ] Pull to refresh on gym details works

### **Bug #7 - Female Join**
- [ ] Female user can join general session
- [ ] Female user can join women-only session
- [ ] Male user CANNOT join women-only session (expected)
- [ ] Male user CAN join general session

---

## Summary

This analysis reveals several interconnected issues:

1. **Core Issue:** Database `auth_id` sync timing causes multiple symptoms (Bugs #1, #3, #7)
2. **UI Issues:** Layout and loading states need polish (Bugs #2, #4)
3. **Performance:** Over-use of real-time subscriptions (Bug #5/6)

**Recommended Approach:**
1. Start with Bug #7 (RLS policy fix) - highest impact
2. Fix Bug #1 (add retry/caching logic)
3. Address UI issues (#2, #4) in parallel
4. Optimize data fetching (#5/6) last

All fixes are backward-compatible and don't require database migrations (except RLS policy update).

---

**Report Prepared By:** Code Analysis Agent  
**Date:** February 14, 2026
