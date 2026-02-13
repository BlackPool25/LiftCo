# LiftCo Architecture & Feature Consistency Audit

Date: 2026-02-13  
Scope: Flutter app (`lib/**`), local SQL migrations (`supabase/migrations/**`), and live Supabase project `bpfptwqysbouppknzaqk` (tables, deployed Edge Functions, migrations, advisors, logs).

---

## 1) Executive Verdict

The current system is **not yet architecture-consistent** with the required model (“edge-function-first, strict RLS, stable UUID identity mapping”).

There are good foundations (UUID app users, women-only field, session join/leave functions, reminders functions, notifications pipeline), but multiple high-impact inconsistencies exist across:

1. **Identity/key lookup strategy** (auth user ID vs app user ID fallback by email/phone).  
2. **Edge Function contracts vs app calls** (notably session cancel path/type mismatch).  
3. **RLS policy intent vs required UX** (host/member visibility and leakage boundaries).  
4. **Direct table access from Flutter despite edge-function-first requirement**.  
5. **Live DB/Function state diverging from local repo migrations and source of truth**.

---

## 2) What Was Verified Against Your Required Flow

## A. Sign-up/Auth Flow

### Implemented
- Google OAuth and email magic-link are implemented in Flutter auth flow.
- Phone OTP client methods exist.
- User profiles use UUID in `public.users.id`.
- `users` table supports nullable `email` and nullable `phone_number`.

### Inconsistencies
1. **Key lookup is unstable and multi-path**
   - App and Edge Functions resolve user profile by trying `auth_id`, then `email`, then `phone_number`.
   - This creates cross-account ambiguity risk if contact attributes change/recycle.
   - Required architecture should be deterministic: `auth.uid()` -> `users.auth_id` -> exactly one `users.id`.

2. **Client and function behavior depend on fallback identity matching**
   - This is brittle for OAuth account linking and phone/email updates.

3. **Phone OTP requirement context mismatch**
   - Requirement says phone OTP is not implemented but user must have email or phone.
   - Live app still exposes phone OTP login flow while local Supabase config (dev) has SMS signup disabled by default.

### Needed changes
- Make `auth_id` mandatory unique mapping for all profile rows.
- Remove fallback profile resolution by email/phone for authorization-critical flows.
- Enforce DB-level check: at least one of `(email, phone_number)` is non-null.

---

## B. Session Listing + Details + Visibility Rules

### Required behavior
- Before join: show host name+age only.
- Before join: hide other member PII with “Join to see other members info”.
- After join: show member names + ages.

### Implemented
- `sessions-get` Edge Function includes host and members with user age/name joins.
- Session details UI shows members and age when data available.

### Inconsistencies
1. **UI does not enforce pre-join hide rule**
   - `SessionDetailsScreen` always renders member cards from `_session.members`.
   - Missing explicit “Join to see other members info” gate.

2. **Host age is not displayed in UI even though required**
   - Host section shows host name but not host age.

3. **RLS + function shape may block required host visibility to non-joined users**
   - Current hardened users policy emphasizes self and same-joined-session members.
   - A non-joined viewer may not be able to see host profile fields from `users` join, conflicting with requirement.

### Needed changes
- Enforce role-based response shaping in `sessions-get`: always include host name+age; include non-host member PII only when requester is joined.
- Update session details UI to honor this contract (do not render member PII pre-join).

---

## C. Women-only Sessions

### Implemented
- `workout_sessions.women_only` exists.
- Session creation UI has women-only option for female users.
- RLS policies include women-only visibility/join checks.

### Inconsistencies
1. **Policy history is fragmented and conflicting**
   - Multiple migration waves overwrite women-only and member policies.
   - Local migrations are not aligned with remote migration history.

2. **Some functions bypass RLS using service role**
   - Any bypass path can silently ignore women-only constraints if not re-checked in function logic.

### Needed changes
- Consolidate policies into one canonical migration set.
- Ensure any service-role function explicitly re-applies women-only authorization checks.

---

## D. Edge-function-first Architecture

### Required behavior
- Session CRUD and sensitive operations should run via Edge Functions, not direct client table access.

### Implemented
- Session create/join/leave/get/cancel APIs exist as functions.

### Inconsistencies
1. **Flutter still directly reads/watches tables in many paths**
   - `home_tab`, `gym_service`, `user_service`, `device_service`, `notification_service`, and membership subscriptions directly query `from(...)` and `stream(...)`.
   - This conflicts with the requested “edge-function-first” and increases RLS coupling in UI.

2. **Function transport layer in app is custom and hardcoded**
   - Hardcoded Supabase project URL and fallback anon key embedded in client service.
   - Not using the SDK-native invoke path (`supabase.functions.invoke`) consistently.

3. **Live edge logs show repeated `401` for `sessions-get` and `sessions-join`**
   - Indicates auth/header/session handling problems in function invocation path.

### Needed changes
- Move read APIs behind edge functions or RPC contracts for all sensitive/session flows.
- Replace manual HTTP function client with `supabase.functions.invoke` adapter.
- Remove hardcoded URL/key from app code.

---

## E. Session Operations Semantics (create/join/leave/cancel)

### Required behavior
- Create: create session + host participation.
- Join: add member + accurate count.
- Leave: only non-host leaves.
- Cancel: host cancels session and clears all memberships.

### Implemented
- Create inserts session and host member.
- Join/leave perform membership updates and notification sends.
- Trigger-based session count management exists.

### Inconsistencies
1. **Cancel flow is functionally broken (critical)**
   - `sessions-delete` parses session ID as integer (`parseInt`) but sessions use UUID.
   - App calls `DELETE sessions-delete?id=<uuid>` while function expects path segment and numeric validation.
   - Result: cancel contract mismatch and likely runtime failure.

2. **Cancel semantics incomplete**
   - Function sets `workout_sessions.status='cancelled'` only.
   - It does not clear member rows/statuses as requested (“remove all members and host also from session”).

3. **Count trigger duplication risk remains**
   - Advisor and migration history indicate multiple counting functions/triggers were repeatedly changed.

### Needed changes
- Fix `sessions-delete` contract to UUID body/path parsing and align with client call.
- On cancel: atomically transition all `session_members` to cancelled (or delete rows if that is canonical), then set session status.
- Keep a single count-sync trigger strategy and remove legacy duplicates.

---

## F. Notifications + Device Opt-in

### Required behavior
- Ask user permission, then register in `user_devices`.
- Toggle should sync with DB flag state.
- Send notifications for join/leave and reminders (2h and 30m).

### Implemented
- `devices-register`, `devices-remove`, `notifications-send`, `session-reminders` functions exist.
- Join/leave functions attempt member notifications.
- Reminder function has 2h and 30m windows.

### Inconsistencies
1. **User consent flow mismatch**
   - Device registration is auto-triggered after auth/profile completion (before explicit settings opt-in decision).

2. **Toggle semantics mismatch with requirement**
   - Requirement expects state flips via validity flag; current disable path removes rows (`devices-remove`) instead of toggling `is_active`.

3. **Security posture of notification send**
   - `notifications-send` has `verify_jwt=false`; auth validation is custom and permissive to any bearer if not tightly checked.

4. **Reminder execution source-of-truth not verified end-to-end**
   - Functions exist and remote migrations suggest cron setup, but SQL-level cron job inspection failed in tooling due MCP runtime errors.

### Needed changes
- Gate device registration behind explicit opt-in UX.
- Use upsert + `is_active` true/false toggle model consistently (avoid delete for normal opt-out).
- Restrict who can call `notifications-send` (service-only pattern + explicit caller verification).

---

## G. Realtime + “At least 10 available sessions” behavior

### Implemented
- Home tab paginates with 10 per page, subscribes to `workout_sessions` streams, and merges updates.
- User schedule subscribes to membership/session changes.
- Filters exist for intensity/time/duration/gym and women mode.

### Inconsistencies
1. **Realtime architecture split**
   - Blend of paginated fetch + global stream + per-session stream creates complexity and potential duplication/race behavior.

2. **Requirement-specific guarantee is not explicit**
   - Logic approximates top sessions merge but does not strictly enforce deterministic “maintain 10 when possible” contract.

### Needed changes
- Define one deterministic feed strategy (server-side ranked list + subscription delta events).
- Explicitly guarantee top-10 replenishment semantics on create/cancel/update events.

---

## 3) Database/RLS/Migration Integrity Findings

## High-risk consistency issues
1. **Local repo migrations are not the live source of truth**
   - Local `supabase/migrations` has a small/older set; remote has a larger, newer timeline (20260207..20260213 with many security and trigger fixes).

2. **Policy churn indicates unstable security model**
   - Repeated migration names focused on RLS recursion fixes, users visibility, and session count corrections.

3. **Advisor warnings in production**
   - Multiple functions have mutable `search_path` warnings (`function_search_path_mutable`).

4. **Some SQL inspection tools failed (`crypto is not defined`)**
   - Prevented direct policy/trigger SQL dump via MCP SQL tool in this run; findings above use available table metadata, migration history, edge code, logs, and advisor output.

---

## 4) Critical Issue List (Priority)

## P0 (must fix before trusting production behavior)
1. **`sessions-delete` UUID/contract bug + cancel behavior incomplete.**
2. **Identity resolution fallback (auth_id/email/phone) used in authorization paths.**
3. **Edge-function/auth invocation instability causing repeated 401s in live logs.**
4. **Direct client table access still used for security-sensitive session/member flows.**

## P1 (security/consistency hardening)
1. **Host/member visibility contract mismatch with required UX and users RLS behavior.**
2. **Notification opt-in flow registers devices before explicit consent.**
3. **Function-level security hardening (`verify_jwt`, caller checks, service-only boundaries).**
4. **Consolidate migration baseline and remove legacy/conflicting policies/triggers.**

## P2 (quality and maintainability)
1. **Single session service architecture (remove duplicated unused `session_service_refactored.dart`).**
2. **Deterministic top-10 realtime feed contract.**
3. **Remove hardcoded Supabase URL/anon key from app service layer.**

---

## 5) Recommended Target Architecture (to align with your requirements)

1. **Identity model**
   - `auth.users.id` -> `public.users.auth_id` unique required.
   - `public.users.id` UUID remains app/domain key everywhere.

2. **Edge API boundary**
   - UI uses only edge endpoints for session lifecycle and sensitive reads.
   - Keep direct table access only for strictly non-sensitive, policy-safe data if absolutely required.

3. **Response shaping by role**
   - `sessions-get` returns host public profile to all eligible viewers.
   - Returns member PII only if requester is joined (or host).

4. **RLS model**
   - Keep RLS enabled on all user/session/device tables.
   - Prefer restrictive, explicit policies; avoid service-role bypass unless absolutely required and then re-check auth logic in function code.

5. **Notification model**
   - Explicit opt-in UX -> device upsert (`is_active=true`).
   - Opt-out -> `is_active=false` (do not delete by default).
   - Join/leave/reminder notifications centralized and idempotent.

---

## 6) Context7 Documentation Alignment Notes

Latest docs reviewed indicate:

- **Supabase Flutter**: preferred Edge Function call path is SDK function invoke with auth context, instead of manual hardcoded HTTP client plumbing.
- **Supabase security guidance**: maintain RLS and least-privilege policy design; avoid broad bypass patterns.
- **FlutterFire messaging**: request permission intentionally, handle `onTokenRefresh`, and keep backend token state synchronized per device lifecycle.

Current implementation is partially aligned but not fully consistent with these recommendations.

---

## 7) Final Assessment

The project is **promising but currently inconsistent** across architecture boundaries (client vs edge vs RLS), identity resolution, and production/source-of-truth management.

Your concerns about **key lookups, edge triggers, migration consistency, and RLS behavior are valid** and confirmed by this audit.

A focused stabilization pass (P0/P1 above) is required before this can be considered a sound, well-thought production architecture.
