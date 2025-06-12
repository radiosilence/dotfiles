#!/bin/bash

# Test script for fastmail-cli using environment variables
# Set these environment variables before running:
# export FASTMAIL_TOKEN="your-api-token"
# export TEST_EMAIL="recipient@example.com"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check if environment variables are set
if [ -z "$FASTMAIL_TOKEN" ]; then
    print_error "FASTMAIL_TOKEN environment variable not set"
    exit 1
fi

if [ -z "$TEST_EMAIL" ]; then
    print_error "TEST_EMAIL environment variable not set"
    exit 1
fi

# Check if CLI is built
if [ ! -f "./bin/fastmail-cli" ]; then
    print_error "fastmail-cli not built. Run: task build"
    exit 1
fi

CLI="./bin/fastmail-cli"

print_step "Testing Fastmail CLI"

# Test authentication
print_step "1. Testing authentication"
auth_result=$($CLI auth "$FASTMAIL_TOKEN")
echo "$auth_result" | jq '.'

if ! echo "$auth_result" | jq -e '.success' > /dev/null; then
    print_error "Authentication failed"
    exit 1
fi

# Test listing mailboxes
print_step "2. Testing list mailboxes"
mailboxes_result=$($CLI list mailboxes)
echo "$mailboxes_result" | jq '.'

# Test listing emails
print_step "3. Testing list emails"
emails_result=$($CLI list emails --limit 5)
echo "$emails_result" | jq '.'

# Test search
print_step "4. Testing search"
search_result=$($CLI search "test")
echo "$search_result" | jq '.'

# Test sending email
print_step "5. Testing send email"
subject="Test email from fastmail-cli $(date)"
body="This is a test email sent using the fastmail-cli tool.

Sent at: $(date)
From: Fastmail CLI Test Script

This tests that our CLI tool can successfully send emails via the JMAP API."

send_result=$($CLI send --to "$TEST_EMAIL" --subject "$subject" --body "$body")
echo "$send_result" | jq '.'

if echo "$send_result" | jq -e '.success' > /dev/null; then
    print_step "✅ All tests passed! Email sent successfully."
else
    print_error "❌ Send test failed"
    exit 1
fi

print_step "Test complete!"