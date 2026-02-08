#!/bin/bash

# Gym Buddy - API Test Script with Real JWT
# This script demonstrates how to get a real JWT token and test endpoints

BASE_URL="https://bpfptwqysbouppknzaqk.supabase.co/functions/v1"

echo "========================================="
echo "Gym Buddy API Test with JWT"
echo "========================================="
echo ""

# For testing, we need to bypass the normal auth flow
# Since the test-signup doesn't return a JWT, we have a few options:

# Option 1: Test with Supabase Service Role Key (Admin access)
# Get this from: Supabase Dashboard > Settings > API > service_role key
# This allows testing without JWT

echo "=== TESTING WITH SERVICE ROLE KEY ==="
echo ""
echo "To test device registration, you need your SERVICE_ROLE_KEY"
echo ""
echo "Get it from: https://app.supabase.com/project/bpfptwqysbouppknzaqk/settings/api"
echo "Copy the 'service_role' secret key"
echo ""
echo "Example:"
echo "curl -X POST \"$BASE_URL/devices-register\" \\"
echo "  -H \"Authorization: Bearer eyJhbGciOiJIUzI1NiIs...\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"fcm_token\": \"test_token_123\", \"device_type\": \"iOS\"}'"
echo ""

# Check if SERVICE_ROLE_KEY is provided
if [ -z "$SERVICE_ROLE_KEY" ]; then
    echo "⚠️  SERVICE_ROLE_KEY not set"
    echo ""
    echo "Set it with: export SERVICE_ROLE_KEY=your_key_here"
    echo ""
    echo "Or test manually with the curl command above"
    exit 1
fi

echo "Testing with SERVICE_ROLE_KEY..."
echo ""

# Test device registration
echo "1. Registering device..."
DEVICE_RESPONSE=$(curl -s -X POST "$BASE_URL/devices-register" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "fcm_token": "test_token_'$(date +%s)'",
    "device_type": "iOS",
    "device_name": "Test iPhone"
  }')

echo "Response:"
echo "$DEVICE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$DEVICE_RESPONSE"
echo ""

# For real user testing, here's the complete flow:
echo ""
echo "=== COMPLETE AUTH FLOW FOR REAL JWT ==="
echo ""
echo "For production testing, use this flow:"
echo ""
echo "Step 1: Request OTP"
echo "-------------------"
echo "curl -X POST \"$BASE_URL/auth-email-request-otp\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\": \"user@example.com\"}'"
echo ""
echo "Step 2: Check email for OTP (or check Supabase Auth logs)"
echo ""
echo "Step 3: Verify OTP"
echo "------------------"
echo "curl -X POST \"$BASE_URL/auth-email-verify-otp\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\": \"user@example.com\", \"otp\": \"123456\"}'"
echo ""
echo "This returns:"
echo '{'
echo '  "session": {'
echo '    "access_token": "eyJhbGciOiJIUzI1NiIs...",  <-- USE THIS'
echo '    "refresh_token": "...",'
echo '    "expires_at": 1234567890'
echo '  }'
echo '}'
echo ""
echo "Step 4: Use access_token in Authorization header"
echo "--------------------------------------------------"
echo "curl -X POST \"$BASE_URL/devices-register\" \\"
echo "  -H \"Authorization: Bearer eyJhbGciOiJIUzI1NiIs...\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"fcm_token\": \"...\", \"device_type\": \"iOS\"}'"
echo ""
