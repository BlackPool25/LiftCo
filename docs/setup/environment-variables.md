# Environment Variables Setup

This document explains all environment variables required for the Gym Buddy application.

## 🔧 Required Variables

### Supabase Configuration

```bash
# Supabase Project URL
SUPABASE_URL=https://bpfptwqysbouppknzaqk.supabase.co

# Supabase Anon Key (Public)
# Used by client applications
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...

# Supabase Service Role Key (Secret!)
# Used by Edge Functions for admin operations
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIs...
```

**Where to find these:**
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Settings → API
4. Copy `URL`, `anon public`, and `service_role secret`

---

## 🔥 Firebase Configuration (For Notifications)

### Option 1: Service Account JSON (Recommended)

```bash
# Firebase Project ID
FIREBASE_PROJECT_ID=gym-buddy-123456

# Complete Service Account JSON (single line)
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"gym-buddy-123456","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-xxx@gym-buddy-123456.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxx%40gym-buddy-123456.iam.gserviceaccount.com"}
```

**How to get Service Account JSON:**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click ⚙️ (Settings) → Project Settings
4. Service Accounts tab
5. Click "Generate new private key"
6. Download JSON file
7. Copy entire JSON content
8. Minify it (remove newlines) for .env file

**Quick minify command:**
```bash
cat service-account.json | jq -c '.'
```

---

## 📝 .env.example Template

Create a `.env` file in your project root:

```bash
# ============================================
# Gym Buddy - Environment Variables
# ============================================

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Firebase Cloud Messaging (FCM)
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

# Optional: Development Settings
SUPABASE_LOCAL=false
LOG_LEVEL=info
```

---

## 🔐 Security Best Practices

### 1. Never Commit Secrets

Add to `.gitignore`:
```gitignore
# Environment variables
.env
.env.local
.env.production

# Firebase credentials
service-account.json
*-credentials.json
```

### 2. Use Different Keys for Different Environments

```bash
# Development
SUPABASE_URL=https://dev-project.supabase.co

# Production
SUPABASE_URL=https://prod-project.supabase.co
```

### 3. Rotate Keys Regularly

- Service account keys should be rotated every 90 days
- Immediately revoke keys if compromised
- Use separate keys for CI/CD

### 4. Limit Service Account Permissions

Only grant necessary permissions:
- ✅ Firebase Cloud Messaging API
- ❌ Avoid owner/admin permissions

---

## 🚀 Setting Up in Supabase

### Step 1: Set Secrets

```bash
# Using Supabase CLI
supabase secrets set FIREBASE_PROJECT_ID=gym-buddy-123456
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# Verify
supabase secrets list
```

### Step 2: Restart Functions

After setting secrets, restart Edge Functions:

```bash
# Redeploy functions to pick up new secrets
supabase functions deploy
```

---

## 🧪 Local Development

### Using .env File

```bash
# 1. Copy template
cp .env.example .env

# 2. Fill in your values
nano .env

# 3. Start Supabase locally
supabase start

# 4. Serve functions locally
supabase functions serve
```

### Using supabase/config.toml

For local development, you can also set secrets in `supabase/config.toml`:

```toml
[functions.notifications-send]
verify_jwt = false

[functions.environment]
FIREBASE_PROJECT_ID = "your-project-id"
```

⚠️ **Note:** Don't commit `config.toml` with secrets!

---

## 🔍 Troubleshooting

### Issue: "FIREBASE_SERVICE_ACCOUNT_JSON not configured"

**Solution:**
```bash
# Check if secret is set
supabase secrets list

# If not, set it
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# Redeploy functions
supabase functions deploy
```

### Issue: "Failed to authenticate with FCM"

**Check:**
1. Service account JSON is valid
2. Firebase project has Cloud Messaging enabled
3. Service account has `roles/firebase.messagingAdmin` permission

### Issue: "Invalid FCM tokens not being deleted"

**Check:**
1. `SUPABASE_SERVICE_ROLE_KEY` is set correctly
2. Function has proper error handling for UNREGISTERED tokens

---

## 📋 Verification Checklist

- [ ] `.env` file created from `.env.example`
- [ ] `SUPABASE_URL` is correct
- [ ] `SUPABASE_ANON_KEY` is set
- [ ] `SUPABASE_SERVICE_ROLE_KEY` is set
- [ ] `FIREBASE_PROJECT_ID` matches your Firebase project
- [ ] `FIREBASE_SERVICE_ACCOUNT_JSON` is valid JSON (minified)
- [ ] `.env` is in `.gitignore`
- [ ] Secrets are set in Supabase Dashboard or CLI
- [ ] Functions are redeployed after secret changes

---

## 🆘 Getting Help

If you're having trouble:

1. Check function logs:
   ```bash
   supabase functions logs notifications-send
   ```

2. Test FCM setup:
   ```bash
   curl -X POST "$BASE_URL/notifications-send" \
     -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "user_ids": [1],
       "title": "Test",
       "body": "Test notification"
     }'
   ```

3. Verify Firebase project settings in console

---

## 📚 Related Documentation

- [Firebase Service Accounts](https://firebase.google.com/support/guides/service-accounts)
- [Supabase Environment Variables](https://supabase.com/docs/guides/functions/secrets)
- [FCM Setup Guide](https://firebase.google.com/docs/cloud-messaging/js/client)
