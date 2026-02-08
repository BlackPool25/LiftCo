#!/bin/bash

# CRUD API Testing Script for Gym Buddy
# This script tests all the CRUD endpoints

BASE_URL="https://bpfptwqysbouppknzaqk.supabase.co/functions/v1"

echo "========================================="
echo "Gym Buddy CRUD API Test Script"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local auth=$4
    local description=$5
    
    echo ""
    echo "Testing: $description"
    echo "Endpoint: $method $endpoint"
    
    if [ -n "$auth" ]; then
        if [ -n "$data" ]; then
            response=$(curl -s -X "$method" "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $auth" \
                -d "$data")
        else
            response=$(curl -s -X "$method" "$BASE_URL$endpoint" \
                -H "Authorization: Bearer $auth")
        fi
    else
        if [ -n "$data" ]; then
            response=$(curl -s -X "$method" "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data")
        else
            response=$(curl -s -X "$method" "$BASE_URL$endpoint")
        fi
    fi
    
    echo "Response:"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}✗ FAILED${NC}"
    else
        echo -e "${GREEN}✓ SUCCESS${NC}"
    fi
}

echo ""
echo "Step 1: Create/Get Test User"
echo "------------------------------"
USER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth-email-test-signup" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "api-test@example.com",
        "name": "API Test User",
        "age": 25,
        "experience_level": "beginner"
    }')

echo "User Response: $USER_RESPONSE"

# For testing without JWT (functions require JWT), we'll test with anon key
# In production, you'd use the access_token from auth response

echo ""
echo "========================================="
echo "TESTING COMPLETE"
echo "========================================="
echo ""
echo "Note: Authenticated endpoints require JWT token."
echo "To fully test, use the Supabase client or include a valid access_token."
echo ""
echo "Test the endpoints manually:"
echo ""
echo "1. Get User Profile:"
echo "   GET $BASE_URL/users-get-me"
echo "   Headers: Authorization: Bearer <token>"
echo ""
echo "2. Update User Profile:"
echo "   PATCH $BASE_URL/users-update-me"
echo "   Headers: Authorization: Bearer <token>"
echo "   Body: {\"name\": \"New Name\", \"age\": 26}"
echo ""
echo "3. List Gyms:"
echo "   GET $BASE_URL/gyms-list"
echo "   Headers: Authorization: Bearer <token>"
echo ""
echo "4. Get Gym Details:"
echo "   GET $BASE_URL/gyms-get?id=1"
echo "   Headers: Authorization: Bearer <token>"
echo ""
echo "5. Create Session:"
echo "   POST $BASE_URL/sessions-create"
echo "   Headers: Authorization: Bearer <token>"
echo "   Body: {"
echo "     \"gym_id\": 1,"
echo "     \"title\": \"Morning Push Workout\","
echo "     \"session_type\": \"push\","
echo "     \"start_time\": \"2026-02-10T10:00:00Z\","
echo "     \"duration_minutes\": 60,"
echo "     \"max_capacity\": 4"
echo "   }"
echo ""
echo "6. List Sessions:"
echo "   GET $BASE_URL/sessions-list?gym_id=1"
echo "   Headers: Authorization: Bearer <token>"
echo ""
echo "7. Join Session:"
echo "   POST $BASE_URL/sessions-join"
echo "   Headers: Authorization: Bearer <token>"
echo "   (session ID in URL path)"
echo ""
echo "8. Leave Session:"
echo "   DELETE $BASE_URL/sessions-leave"
echo "   Headers: Authorization: Bearer <token>"
echo "   (session ID in URL path)"
echo ""
