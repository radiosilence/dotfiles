#!/bin/bash

# XLD Profile Debugging Script
# Helps diagnose and fix XLD profile issues

set -e

echo "🔍 XLD Profile Debugging Script"
echo "================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Check if XLD is installed
echo "1. Checking XLD installation..."
if [ -d "/Applications/XLD.app" ]; then
  print_status $GREEN "✅ XLD is installed at /Applications/XLD.app"
  XLD_VERSION=$(plutil -p "/Applications/XLD.app/Contents/Info.plist" | grep "CFBundleShortVersionString" | cut -d'"' -f4)
  echo "   Version: $XLD_VERSION"
else
  print_status $RED "❌ XLD is not installed"
  echo "   Please install XLD from: https://tmkk.undo.jp/xld/index_e.html"
  exit 1
fi
echo

# Check if XLD is running
echo "2. Checking XLD process..."
if pgrep -f "XLD" >/dev/null; then
  print_status $YELLOW "⚠️  XLD is currently running (PID: $(pgrep -f XLD))"
  echo "   Note: XLD should be quit before modifying profiles"
else
  print_status $GREEN "✅ XLD is not running"
fi
echo

# Check XLD preferences
echo "3. Checking XLD preferences..."
PLIST_PATH="$HOME/Library/Preferences/jp.tmkk.XLD.plist"
if [ -f "$PLIST_PATH" ]; then
  print_status $GREEN "✅ XLD preferences found at $PLIST_PATH"
  echo "   File size: $(ls -lh "$PLIST_PATH" | awk '{print $5}')"
  echo "   Modified: $(ls -l "$PLIST_PATH" | awk '{print $6, $7, $8}')"
else
  print_status $RED "❌ XLD preferences not found"
  echo "   Please run XLD at least once to create preferences"
  exit 1
fi
echo

# Check if Profiles key exists
echo "4. Checking Profiles structure..."
if plutil -extract Profiles xml1 -o - "$PLIST_PATH" >/dev/null 2>&1; then
  print_status $GREEN "✅ Profiles key exists in preferences"

  # Count profiles
  PROFILE_COUNT=$(plutil -extract Profiles xml1 -o - "$PLIST_PATH" | grep -c '<dict>' || echo "0")
  echo "   Number of profiles: $PROFILE_COUNT"

  if [ "$PROFILE_COUNT" -gt 0 ]; then
    echo "   Profile details:"

    # Extract profile names
    PROFILE_XML=$(plutil -extract Profiles xml1 -o - "$PLIST_PATH" 2>/dev/null)
    echo "$PROFILE_XML" | grep -A1 '<key>name</key>' | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/     - \1/'
  fi
else
  print_status $YELLOW "⚠️  No Profiles key found in preferences"
  echo "   This is normal if no profiles have been created yet"
fi
echo

# Check specific rip-cd profiles
echo "5. Checking for rip-cd profiles..."
PROFILES_TO_CHECK=("flac_rip" "secure_rip")
for profile in "${PROFILES_TO_CHECK[@]}"; do
  if plutil -extract Profiles xml1 -o - "$PLIST_PATH" 2>/dev/null | grep -q "<string>$profile</string>"; then
    print_status $GREEN "✅ Found profile: $profile"
  else
    print_status $YELLOW "⚠️  Profile not found: $profile"
  fi
done
echo

# Check XLD profile directory (if it exists)
echo "6. Checking XLD profile directory..."
PROFILE_DIR="$HOME/Library/Application Support/XLD/Profiles"
if [ -d "$PROFILE_DIR" ]; then
  print_status $GREEN "✅ XLD profile directory exists: $PROFILE_DIR"
  PROFILE_FILES=$(ls -1 "$PROFILE_DIR" 2>/dev/null | wc -l)
  echo "   Profile files: $PROFILE_FILES"
  if [ "$PROFILE_FILES" -gt 0 ]; then
    echo "   Files:"
    ls -1 "$PROFILE_DIR" | sed 's/^/     - /'
  fi
else
  print_status $YELLOW "⚠️  XLD profile directory not found"
  echo "   This may be normal - XLD might store profiles only in plist"
fi
echo

# Test profile creation
echo "7. Testing profile creation..."
if [ "$PROFILE_COUNT" -eq 0 ]; then
  print_status $YELLOW "⚠️  No profiles exist - this might indicate an issue"
  echo "   Recommendation: Create a test profile manually in XLD GUI"
else
  print_status $GREEN "✅ Profiles exist - automatic creation should work"
fi
echo

# Check profile structure
echo "8. Analyzing profile structure..."
if [ "$PROFILE_COUNT" -gt 0 ]; then
  echo "   Extracting first profile for analysis..."
  FIRST_PROFILE=$(plutil -extract Profiles.0 xml1 -o - "$PLIST_PATH" 2>/dev/null)

  # Check for required keys
  REQUIRED_KEYS=("name" "RipperMode" "TestAndCopy" "UseC2Pointer" "QueryAccurateRip" "RetryCount" "SaveLogMode")
  for key in "${REQUIRED_KEYS[@]}"; do
    if echo "$FIRST_PROFILE" | grep -q "<key>$key</key>"; then
      print_status $GREEN "   ✅ Has key: $key"
    else
      print_status $YELLOW "   ⚠️  Missing key: $key"
    fi
  done
else
  print_status $YELLOW "⚠️  No profiles to analyze"
fi
echo

# Recommendations
echo "9. Recommendations:"
echo "=================="

if [ "$PROFILE_COUNT" -eq 0 ]; then
  print_status $YELLOW "📝 No profiles found. Try these steps:"
  echo "   1. Open XLD"
  echo "   2. Go to Preferences → Profiles"
  echo "   3. Create a test profile manually"
  echo "   4. Quit XLD and run this script again"
  echo "   5. If manual creation works, automatic creation should work too"
elif pgrep -f "XLD" >/dev/null; then
  print_status $YELLOW "📝 XLD is running. Try these steps:"
  echo "   1. Quit XLD completely"
  echo "   2. Run 'rip-cd setup' again"
  echo "   3. Start XLD and check Profiles menu"
else
  print_status $GREEN "📝 Setup looks good. Try these steps:"
  echo "   1. Start XLD"
  echo "   2. Check Preferences → Profiles"
  echo "   3. If profiles don't appear, try restarting XLD"
  echo "   4. If still no profiles, create them manually"
fi
echo

# Offer to backup/restore profiles
echo "10. Backup/Restore Options:"
echo "=========================="
echo "Backup current profiles:"
echo "   cp '$PLIST_PATH' '$PLIST_PATH.backup'"
echo
echo "Restore from backup:"
echo "   cp '$PLIST_PATH.backup' '$PLIST_PATH'"
echo
echo "Clear all profiles (DESTRUCTIVE):"
echo "   plutil -remove Profiles '$PLIST_PATH' 2>/dev/null || echo 'No profiles to remove'"
echo

# Show raw profile data if requested
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  echo "11. Raw Profile Data:"
  echo "===================="
  if [ "$PROFILE_COUNT" -gt 0 ]; then
    echo "Full Profiles XML:"
    plutil -extract Profiles xml1 -o - "$PLIST_PATH" 2>/dev/null | head -50
    echo "..."
  else
    echo "No profiles to display"
  fi
fi

echo
print_status $BLUE "🔧 Debug complete. Run with --verbose for more details."
echo
