# Gym Buddy - Authentication Quick Reference

## ✅ What's Implemented

### 1. Edge Functions (8 total)

**Phone Authentication:**
| Function | Purpose | JWT Required |
|----------|---------|--------------|
| `auth-request-otp` | Send OTP to phone | No |
| `auth-verify-otp` | Verify phone OTP code | No |
| `auth-complete-profile` | Create profile after phone auth | Yes |
| `auth-test-signup` | Test signup without OTP | No |

**Email Authentication (FREE!):**
| Function | Purpose | JWT Required |
|----------|---------|--------------|
| `auth-email-request-otp` | Send OTP to email | No |
| `auth-email-verify-otp` | Verify email OTP code | No |
| `auth-email-complete-profile` | Create profile after email auth | Yes |
| `auth-email-test-signup` | Test signup without OTP | No |

### 2. Authentication Flow (Same for Phone & Email)

**Option A: Phone OTP (Paid - requires SMS provider)**
```
1. POST /auth-request-otp
   Body: {"phone": "+15551234567"}
   → Sends SMS OTP

2. POST /auth-verify-otp
   Body: {"phone": "+15551234567", "otp": "123456"}
   → Returns session + isProfileComplete flag

3. If isProfileComplete = false:
   POST /auth-complete-profile
   Headers: Authorization: Bearer <token>
   Body: {"name": "John", "age": 25, ...}
   → Creates user profile in database
```

**Option B: Email OTP (FREE - uses Supabase built-in service)**
```
1. POST /auth-email-request-otp
   Body: {"email": "user@example.com"}
   → Sends Email OTP

2. POST /auth-email-verify-otp
   Body: {"email": "user@example.com", "otp": "123456"}
   → Returns session + isProfileComplete flag

3. If isProfileComplete = false:
   POST /auth-email-complete-profile
   Headers: Authorization: Bearer <token>
   Body: {"name": "John", "age": 25, ...}
   → Creates user profile in database
```

### 3. Database Integration

- ✅ Users stored in `users` table
- ✅ Phone number linked to Supabase Auth (optional)
- ✅ Email linked to Supabase Auth (optional)
- ✅ RLS policies protect user data
- ✅ Profile fields: name, age, gender, workout_split, etc.

### 4. Security

- ✅ Phone format validation (E.164)
- ✅ Email format validation
- ✅ JWT token authentication
- ✅ Row Level Security on users table
- ✅ Service role for Edge Functions

---

## 🧪 Quick Test - Email Auth (Recommended)

### Test Email Signup (Development)
```bash
curl -X POST "https://bpfptwqysbouppknzaqk.supabase.co/functions/v1/auth-email-test-signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "phone_number": "+15559876543",
    "age": 28,
    "gender": "female",
    "current_workout_split": "legs",
    "time_working_out_months": 18,
    "experience_level": "advanced",
    "primary_activity": "crossfit",
    "bio": "Love heavy lifting!"
  }'
```

### Verify User Created
```sql
SELECT id, name, email, phone_number, age, gender, experience_level, bio 
FROM users 
WHERE email = 'test@example.com';
```

---

## 📁 Files Created

1. `auth-api-documentation.md` - Complete API documentation
2. `database-schema.md` - Database schema reference
3. Edge Functions deployed to Supabase project

---

## 🔧 Next Steps

### 1. Choose Authentication Method

**Recommended: Email OTP (FREE)**
- Uses Supabase built-in email service
- 500 emails/day with Gmail SMTP
- No additional provider needed

**Alternative: Phone OTP (PAID)**
- Requires SMS provider (Twilio/Vonage)
- Better for mobile-first apps
- Higher user trust in some markets

### 2. Configure Provider (Production)

**For Email OTP:**
1. Supabase Dashboard → Auth → Providers → Email
2. Enable it
3. Configure SMTP settings
4. Free options: Gmail (500/day), SendGrid (100/day)

**For Phone OTP:**
1. Supabase Dashboard → Auth → Providers → Phone
2. Enable it
3. Add Twilio/Vonage credentials

### 3. Remove Test Endpoints (before production)
```bash
# Remove phone test endpoint
supabase functions delete auth-test-signup

# Remove email test endpoint
supabase functions delete auth-email-test-signup
```

### 4. Add Profile Photo Upload
- Create Supabase Storage bucket
- Add upload endpoint

### 5. Client Integration
- Use Supabase client in Flutter app
- Store access_token securely
- Handle token refresh

---

## 📱 API Endpoints

**Base URL:** `https://bpfptwqysbouppknzaqk.supabase.co/functions/v1`

### Phone Authentication
| Endpoint | Method | Headers | Body |
|----------|--------|---------|------|
| `/auth-request-otp` | POST | Content-Type | `{phone}` |
| `/auth-verify-otp` | POST | Content-Type | `{phone, otp}` |
| `/auth-complete-profile` | POST | Authorization + Content-Type | `{name, age, ...}` |
| `/auth-test-signup` | POST | Content-Type | `{phone, name, ...}` |

### Email Authentication (FREE!)
| Endpoint | Method | Headers | Body |
|----------|--------|---------|------|
| `/auth-email-request-otp` | POST | Content-Type | `{email}` |
| `/auth-email-verify-otp` | POST | Content-Type | `{email, otp}` |
| `/auth-email-complete-profile` | POST | Authorization + Content-Type | `{name, age, ...}` |
| `/auth-email-test-signup` | POST | Content-Type | `{email, name, ...}` |

---

## 💰 Cost Comparison

| Feature | Email OTP | Phone OTP |
|---------|-----------|-----------|
| **Setup Cost** | FREE | Paid provider required |
| **Per Authentication** | FREE* | $0.01-$0.10 per SMS |
| **Daily Limit** | 500 emails (Gmail) | Based on provider |
| **User Experience** | Check email inbox | Instant SMS delivery |
| **Best For** | Web apps, cost-conscious | Mobile-first apps |

*Free with Gmail SMTP or free tiers of SendGrid/Mailgun

---

## 🎯 Key Features

✅ **Email OTP authentication** - FREE using Supabase  
✅ **Phone OTP authentication** - With SMS provider  
✅ **Automatic user detection** - Signup vs login  
✅ **Profile completion** - For new users  
✅ **JWT session management** - Secure tokens  
✅ **Data validation** - Email & phone constraints  
✅ **RLS security policies** - Row level security  
✅ **Postman/cURL ready** - Easy testing  

---

## 📚 Documentation

- Full API docs: `auth-api-documentation.md`
- Database schema: `database-schema.md`
- Project context: `Project-Context.md`

**Tested:** ✅ Email & Phone auth working, data stored in database

---

## 🚀 Recommendation

**Use Email OTP for MVP** because:
1. ✅ Completely FREE (no SMS costs)
2. ✅ Supabase built-in support
3. ✅ Easy to test and develop
4. ✅ Can add Phone auth later

**Add Phone OTP later** when:
- Budget allows for SMS costs
- Mobile app prioritizes SMS
- Target market prefers phone auth
