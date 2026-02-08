# Project Build Order & Verification Strategy

Based on your research, here's a **pragmatic, testable approach** to building this app without getting overwhelmed:

---

## Phase 1: Core MVP (Weeks 1-4)
**Goal**: Prove the session-based model works with manual verification

### Week 1-2: Backend Foundation
**Build Order:**

1. **Database Setup First** (Day 1-2)
   - Set up Supabase/Firebase project
   - Create these 3 tables ONLY:
     - `users` (id, phone, name, home_gym_id)
     - `gyms` (id, name, address, lat, lng)
     - `workout_sessions` (session_id, gym_id, host_user_id, activity_type, start_time, max_capacity, current_count, status)
   
   **Verify**: Can you manually add a gym and a user via Supabase dashboard?

2. **Auth System** (Day 3-4)
   - Phone OTP login (use Supabase Auth or Firebase Auth)
   - Store user in database after first login
   
   **Verify**: Can you login via phone number in Postman/curl?

3. **Session CRUD APIs** (Day 5-7)
   ```
   POST /sessions (create session)
   GET /gyms/{gym_id}/sessions (view sessions)
   POST /sessions/{session_id}/join (join session)
   ```
   
   **Verify**: Use Postman to:
   - Create a session
   - Fetch sessions for a gym
   - Join a session
   - Check that `current_count` increments

4. **Basic Notification** (Day 8-10)
   - Set up Firebase Cloud Messaging
   - Send push notification when someone joins your session
   
   **Verify**: Create session from one phone, join from another phone, see notification

---

### Week 3-4: Mobile App (Manual Verification Version)

**Build Order:**

1. **Onboarding Flow** (Day 11-14)
   - Phone login screen
   - Select your gym (hardcode 1-2 gyms for now)
   - Basic profile (name, usual time, activity type)
   
   **Verify**: Can you complete signup and reach the home screen?

2. **Session Board View** (Day 15-18)
   - List view of sessions at selected gym
   - "Create Session" button → form (activity, time, slots)
   - "Join" button on each session
   
   **Verify**: 
   - Create session on Phone A
   - See it appear on Phone B
   - Join from Phone B
   - See "2/4 slots filled"

3. **Manual Check-in Button** (Day 19-21)
   - Simple "I'm at the gym" button
   - Shows "Waiting for buddies..." until others check in
   - Shows "Streak saved!" when all squad members check in
   
   **Verify**: 
   - Join same session from 2 phones
   - Both press "I'm at gym" 
   - Both see "Streak saved!"

**🎯 MILESTONE 1**: You now have a working session-based app with manual verification. Test with 5-10 friends at ONE gym for 1 week.

---

## Phase 2: Add GPS Verification (Weeks 5-6)
**Goal**: Remove manual check-in friction

### Week 5: GPS Backend

1. **Geofence Table** (Day 22-23)
   - Add `geo_polygon` or `radius` to `gyms` table
   - For MVP, just store `latitude`, `longitude`, `radius_meters`

2. **Location Verification Endpoint** (Day 24-26)
   ```
   POST /checkins
   Body: { user_id, gym_id, latitude, longitude, timestamp }
   ```
   - Backend checks: Is user's lat/lng within gym's radius?
   - If yes, create `checkins` record
   
   **Verify**: Send fake coordinates via Postman, check if verification works

3. **Auto-Streak Checker** (Day 27-28)
   - Background job (every 5 mins during gym hours)
   - For each active session, check if all members have recent checkins
   - If yes, mark session as "completed" and increment streaks
   
   **Verify**: Manually insert checkin records, wait 5 mins, check if streaks update

---

### Week 6: GPS Frontend

1. **Location Permission** (Day 29-30)
   - Request location permission on app start
   - Send location to backend every 5 mins when session is active

2. **Passive Verification UI** (Day 31-33)
   - Remove "I'm at gym" button
   - Show status: "Verifying location..." → "At gym ✓" → "Streak saved!"
   
   **Verify**: 
   - Go to actual gym with 2 phones
   - Join same session
   - See automatic verification happen

**🎯 MILESTONE 2**: GPS auto-verification works. Test with same 5-10 friends for another week.

---

## Phase 3: Safety & Anti-Dating (Weeks 7-8)
**Goal**: Make it safe enough to expand beyond friends

### Week 7: Profile & Photo Verification

1. **Photo Upload** (Day 34-36)
   - Add profile photo upload to onboarding
   - Store in Cloudinary/S3
   - Display small photo in session list

2. **Basic Liveness Check** (Day 37-39)
   - Use a library like `react-native-vision-camera`
   - Ask user to take a selfie during signup
   - For MVP, just store it (don't verify yet - manual review is fine)
   
   **Verify**: Photos appear in profiles

### Week 8: Safety Features

1. **Women-Only Filter** (Day 40-42)
   - Add `gender` field to user profile
   - Add toggle: "Show only women's sessions"
   - Filter sessions API by gender
   
   **Verify**: Female user sees only sessions created by females

2. **Report System** (Day 43-45)
   - Add "Report" button on profiles
   - Simple form: "Inappropriate behavior" / "Harassment" / "No-show"
   - Stores report in database (manual review for MVP)
   
   **Verify**: Can submit report, see it in admin dashboard

3. **Reputation Score Display** (Day 46-49)
   - Show "Show-up rate: 85%" on profiles
   - Calculate from: (completed_sessions / total_joined_sessions)
   
   **Verify**: User who flakes has lower score

**🎯 MILESTONE 3**: Safe enough to test with strangers. Recruit 20 people at ONE gym.

---

## Phase 4: Polish & Launch Prep (Weeks 9-10)

1. **Chat System** (Week 9)
   - Use Supabase Realtime or Firebase Firestore for chat
   - Contextual: Only unlocks after joining session
   - Quick action buttons: "Running late", "I'm here"

2. **Admin Panel** (Week 10)
   - Simple web page to view:
     - All gyms and sessions
     - Reports queue
     - User stats
   - Ability to ban users

**🎯 MILESTONE 4**: Launch to 50 people at ONE gym.

---

## Testing Strategy for Each Phase

### Phase 1 Testing (Manual)
**Who**: You + 3-5 close friends who go to the same gym

**Test**:
- Can everyone create and join sessions?
- Does it feel less awkward than asking strangers?
- Do people actually show up?

**Success Criteria**: 3+ sessions completed in 1 week

---

### Phase 2 Testing (GPS)
**Who**: Same group

**Test**:
- Does GPS verification work reliably at your gym?
- Do people get false negatives (at gym but not detected)?
- Is battery drain acceptable?

**Success Criteria**: 80%+ verification accuracy

---

### Phase 3 Testing (Safety)
**Who**: Expand to 10-20 people (include women you don't know personally)

**Test**:
- Do women feel safe using the app?
- Are there any creepy behaviors?
- Do people trust the photo verification?

**Success Criteria**: 
- Zero harassment reports
- 50%+ female users retained after 1 week

---

### Phase 4 Testing (Scale)
**Who**: Open to 50+ people at ONE gym

**Test**:
- Is there always at least 1 session available at peak times?
- Are sessions filling up?
- Are people coming back?

**Success Criteria**:
- 20+ active weekly users
- 10+ sessions completed per week
- 40%+ weekly retention

---

## What NOT to Build (Yet)

❌ **Don't build these until Milestone 3:**
- Advanced AI matching algorithms
- Multi-gym membership
- Workout program sharing
- Leaderboards
- Wearable integration
- Complex gamification beyond streaks

❌ **Don't launch at multiple gyms until:**
- You have 30+ active users at your first gym
- 80%+ session completion rate
- Verified the GPS works reliably

---

## Quick Start Checklist (This Week)

### If starting from zero:

**Day 1:**
- [ ] Create Supabase account
- [ ] Set up database with `users`, `gyms`, `workout_sessions` tables
- [ ] Manually add 1 gym (your gym)

**Day 2:**
- [ ] Set up phone auth in Supabase
- [ ] Test login via Postman

**Day 3:**
- [ ] Write `POST /sessions` endpoint
- [ ] Test creating a session via Postman

**Day 4:**
- [ ] Write `GET /gyms/{id}/sessions` endpoint
- [ ] Test fetching sessions via Postman

**Day 5:**
- [ ] Start Flutter/React Native project
- [ ] Build login screen
- [ ] Connect to your auth backend

**By end of Week 1**: You should be able to login via phone and see "home screen"

---

## Decision Framework: "Am I building the right thing?"

Before coding ANY feature, ask:

1. **Does this help 2 strangers meet at a gym safely?** (Core value)
2. **Can I test this with 5 people in 1 week?** (Fast feedback)
3. **What's the simplest version?** (MVP mindset)

If answer to any is "No" → Don't build it yet.

---

## My Recommendation: Start Here Tomorrow

```
1. Set up Supabase (2 hours)
2. Create 3 tables (1 hour)
3. Build phone auth (3 hours)
4. Build "Create Session" API (4 hours)
```

**By end of tomorrow**: You should be able to create a session via Postman.

**Then** start the mobile app.

---

