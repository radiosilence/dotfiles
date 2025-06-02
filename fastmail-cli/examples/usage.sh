#!/bin/bash

# Example usage script for fastmail-cli
# This demonstrates how to use the CLI and parse its JSON output

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check if fastmail-cli is available
if ! command -v fastmail-cli &> /dev/null; then
    print_error "fastmail-cli not found. Please build and install it first."
    echo "Run: task setup && task install-local"
    exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    print_warning "jq not found. JSON output will not be formatted."
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

format_json() {
    if [ "$JQ_AVAILABLE" = true ]; then
        jq '.'
    else
        cat
    fi
}

# Example 1: Authentication (requires manual token input)
print_step "Step 1: Authentication"
echo "To authenticate, you need a Fastmail API token."
echo "Get one from: Settings → Privacy & Security → Integrations"
echo ""
echo "Example command:"
echo "  fastmail-cli auth YOUR_TOKEN_HERE"
echo ""

# Check if already authenticated
auth_result=$(fastmail-cli list mailboxes 2>&1)
if echo "$auth_result" | grep -q '"success":true'; then
    print_step "Already authenticated! ✓"
else
    print_warning "Not authenticated. Please run: fastmail-cli auth YOUR_TOKEN"
    echo "Showing example outputs with mock data below..."
    exit 0
fi

# Example 2: List mailboxes
print_step "Step 2: List all mailboxes"
echo "Command: fastmail-cli list mailboxes"
mailboxes=$(fastmail-cli list mailboxes)
echo "$mailboxes" | format_json
echo ""

# Extract mailbox names for later use
if [ "$JQ_AVAILABLE" = true ]; then
    mailbox_names=$(echo "$mailboxes" | jq -r '.data[].name' | head -3)
    echo "Available mailboxes:"
    echo "$mailbox_names"
else
    echo "Install jq to see parsed mailbox names"
fi
echo ""

# Example 3: List emails from INBOX
print_step "Step 3: List recent emails from INBOX"
echo "Command: fastmail-cli list emails --limit 5"
emails=$(fastmail-cli list emails --limit 5)
echo "$emails" | format_json
echo ""

# Extract first email ID for example
if [ "$JQ_AVAILABLE" = true ]; then
    first_email_id=$(echo "$emails" | jq -r '.data[0].id // empty')
    if [ -n "$first_email_id" ]; then
        echo "First email ID: $first_email_id"
    fi
fi
echo ""

# Example 4: Get specific email (if we have an ID)
if [ -n "$first_email_id" ]; then
    print_step "Step 4: Get full email details"
    echo "Command: fastmail-cli get email $first_email_id"
    fastmail-cli get email "$first_email_id" | format_json
    echo ""
fi

# Example 5: Search emails
print_step "Step 5: Search emails"
echo "Command: fastmail-cli search 'from:noreply'"
search_result=$(fastmail-cli search 'from:noreply')
echo "$search_result" | format_json
echo ""

# Example 6: Using different mailbox
print_step "Step 6: List emails from Sent folder"
echo "Command: fastmail-cli list emails --mailbox Sent --limit 3"
sent_emails=$(fastmail-cli list emails --mailbox "Sent" --limit 3)
echo "$sent_emails" | format_json
echo ""

# Example 7: Parsing JSON with jq (advanced examples)
if [ "$JQ_AVAILABLE" = true ]; then
    print_step "Step 7: Advanced JSON parsing examples"
    
    echo "Extract just email subjects:"
    echo "$emails" | jq -r '.data[].subject'
    echo ""
    
    echo "Count unread emails per mailbox:"
    echo "$mailboxes" | jq -r '.data[] | "\(.name): \(.unreadEmails) unread"'
    echo ""
    
    echo "Extract sender email addresses:"
    echo "$emails" | jq -r '.data[].from[].email'
    echo ""
    
    echo "Filter emails with attachments:"
    echo "$emails" | jq '.data[] | select(.hasAttachment == true) | {subject, from: .from[].email}'
    echo ""
fi

print_step "Usage complete!"
echo "The fastmail-cli tool outputs structured JSON that can be:"
echo "- Parsed with jq for shell scripts"
echo "- Consumed by other tools and APIs"
echo "- Used by AI assistants like Claude"
echo ""
echo "All commands return JSON with this structure:"
echo '{"success": true/false, "data": {...}, "error": "..."}'