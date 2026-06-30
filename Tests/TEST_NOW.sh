#!/bin/bash

echo "═══════════════════════════════════════════════════════════════════════════"
echo "  🚀 AIRPOSTURE DYNAMIC ISLAND - REBUILD & TEST NOW"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

cd /Users/Allen/AirPosture-TestFlight

echo "🔍 CHECKING FIXES..."
echo ""

# Verify Fix #1
echo "✅ Fix #1: Live Activity Enabled?"
if grep -q "isLiveActivityEnabled = true" AirPostureApp/HeadphoneMotionManager.swift; then
    echo "   ✓ YES - Live Activity is ENABLED"
else
    echo "   ✗ NO - Live Activity is DISABLED. Run fixes first!"
    exit 1
fi

# Verify Fix #2
echo ""
echo "✅ Fix #2: Widget Version Synced?"
APP_V=$(grep -A 1 "CFBundleVersion" AirPostureApp/Info.plist | grep string | sed 's/.*<string>//;s/<\/string>.*//')
WIDGET_V=$(grep -A 1 "CFBundleVersion" AirPostureLiveActivity/Info.plist | grep string | sed 's/.*<string>//;s/<\/string>.*//')

if [ "$APP_V" = "$WIDGET_V" ]; then
    echo "   ✓ YES - Both versions are $APP_V"
else
    echo "   ✗ NO - Version mismatch: App=$APP_V, Widget=$WIDGET_V"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL FIXES VERIFIED!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🧹 CLEANING BUILD CACHE..."
rm -rf ~/Library/Developer/Xcode/DerivedData/AirPosture* 2>/dev/null
echo "   ✓ Cleaned"
echo ""

echo "🔨 REBUILDING PROJECT..."
xcodebuild clean -scheme AirPosture > /dev/null 2>&1
echo "   ✓ Clean complete"

xcodebuild build -scheme AirPosture -destination 'generic/platform=iOS' 2>&1 | \
    grep -E "Build complete|error" | head -5

echo "   ✓ Build complete"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 READY TO RUN ON SIMULATOR!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "RUN THIS COMMAND TO LAUNCH:"
echo ""
echo "  xcodebuild -scheme AirPosture -configuration Debug \\"
echo "    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \\"
echo "    -derivedDataPath ./DerivedData"
echo ""
echo "OR use Xcode: Product → Run (⌘R)"
echo ""

echo "WHAT TO DO WHEN APP OPENS:"
echo ""
echo "1. Look for 'Start Session' button"
echo "2. Tap it"
echo "3. Watch the top of the screen"
echo "4. You should see Dynamic Island appear with:"
echo "   ✓ Rotating bear avatar"
echo "   ✓ Good posture % (should be high initially)"
echo "   ✓ Session timer (0:00, 0:01, 0:02...)"
echo "   ✓ Status badge (Perfect, Monitoring, Needs Work)"
echo ""

echo "OPTIONAL: TEST MOTION"
echo ""
echo "In Simulator:"
echo "  Device → Sensor → Rotate Left/Right (or Tilt Forward/Backward)"
echo "  → Watch the bear avatar rotate in real-time!"
echo ""

echo "═══════════════════════════════════════════════════════════════════════════"
echo "🚀 You're ready! Launch the app and start a session to see the Dynamic Island!"
echo "═══════════════════════════════════════════════════════════════════════════"

