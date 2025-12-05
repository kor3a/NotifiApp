#!/bin/bash
# Reset notification permissions for the app

# Your app's bundle identifier
BUNDLE_ID="com.kor3a.nearbuy"

echo "🔄 Resetting notification permissions for: $BUNDLE_ID"
echo ""

# List available simulators
echo "📱 Available Simulators:"
xcrun simctl list devices | grep "Booted"

echo ""
echo "Resetting permissions for booted simulator..."

# Reset all privacy permissions for the app
xcrun simctl privacy booted reset all "$BUNDLE_ID"

if [ $? -eq 0 ]; then
    echo "✅ Permissions reset successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Delete the app from the simulator (long press → Remove App)"
    echo "2. In Xcode: Product → Clean Build Folder (Cmd+Shift+K)"
    echo "3. Run the app again"
    echo "4. Grant permissions when prompted"
    echo "5. Check console for new debug output"
else
    echo "❌ Failed to reset permissions"
    echo "   Make sure you updated BUNDLE_ID in this script"
fi
