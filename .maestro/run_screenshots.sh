#!/bin/bash
# Run Maestro screenshots for Komodo Go on iPhone simulator
# Usage:
#   ./run_screenshots.sh              # Mixed mode (first 3 dark, rest light)
#   ./run_screenshots.sh mixed        # Mixed mode (first 3 dark, rest light)
#   ./run_screenshots.sh light        # Light mode only
#   ./run_screenshots.sh dark         # Dark mode only
#   ./run_screenshots.sh all          # Run both light and dark mode

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/screenshots"
APP_ID="com.brubytes.komodoGo"
MODE_FILTER="${1:-mixed}"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# iPhone 14 Plus for 6.5" App Store screenshots (1284x2778)
DEVICE_NAME="iPhone 14 Plus"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.png

# Function to collect screenshots with prefix
collect_screenshots() {
    local PREFIX="$1"
    echo "Collecting screenshots for $PREFIX..."

    # Find the most recent test directory
    LATEST_DIR=$(ls -td ~/.maestro/tests/*/ 2>/dev/null | head -1)

    local found=false

    if [ -n "$LATEST_DIR" ]; then
        while IFS= read -r f; do
            local filename=$(basename "$f")
            # Match screenshot names like 01_home_dashboard.png
            if [[ "$filename" =~ ([0-9]{2})_([a-z_]+\.png) ]]; then
                local index=${BASH_REMATCH[1]}
                local base="${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
                local name_prefix="$PREFIX"
                if [ "$PREFIX" = "mixed" ]; then
                    if [ "$index" -le 03 ]; then
                        name_prefix="dark"
                    else
                        name_prefix="light"
                    fi
                fi
                local newname="${name_prefix}_${base}"
                cp "$f" "$OUTPUT_DIR/$newname"
                echo "  -> $newname"
                found=true
            fi
        done < <(find "$LATEST_DIR" -maxdepth 3 -name "*.png" 2>/dev/null)
    fi

    while IFS= read -r f; do
        local filename=$(basename "$f")
        if [[ "$filename" =~ ([0-9]{2})_([a-z_]+\.png) ]]; then
            local index=${BASH_REMATCH[1]}
            local base="${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
            local name_prefix="$PREFIX"
            if [ "$PREFIX" = "mixed" ]; then
                if [ "$index" -le 03 ]; then
                    name_prefix="dark"
                else
                    name_prefix="light"
                fi
            fi
            local newname="${name_prefix}_${base}"
            cp "$f" "$OUTPUT_DIR/$newname"
            echo "  -> $newname"
            found=true
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "*.png" 2>/dev/null)

    if [ "$found" = false ]; then
        if [ -n "$LATEST_DIR" ]; then
            echo "  (no screenshots found in $LATEST_DIR or $SCRIPT_DIR)"
        else
            echo "  (no screenshots found in $SCRIPT_DIR)"
        fi
    else
        # Clean up local screenshots after copying
        rm -f "$SCRIPT_DIR"/*.png
    fi
}

# Get device UDID
get_device_udid() {
    xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'] == '$DEVICE_NAME' and d.get('isAvailable', False):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null | head -1
}

DEVICE_UDID=$(get_device_udid)

if [ -z "$DEVICE_UDID" ]; then
    echo "Error: Device '$DEVICE_NAME' not found or not available."
    echo ""
    echo "Available devices:"
    xcrun simctl list devices available | grep -E "iPhone|iPad"
    exit 1
fi

echo "========================================"
echo "Komodo Go Screenshot Runner"
echo "========================================"
echo "Device: $DEVICE_NAME"
echo "UDID: $DEVICE_UDID"
echo "Output: $OUTPUT_DIR"
echo "========================================"

# Boot device if not booted
echo "Booting simulator..."
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
sleep 3

# Find and install app
echo "Looking for app bundle..."
APP_PATH="$PROJECT_ROOT/build/ios/iphonesimulator/Runner.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Runner.app not found at $APP_PATH. Building app for simulator..."
    cd "$PROJECT_ROOT"
    fvm flutter build ios --simulator --dart-define=KOMODO_DEMO_MODE=true
fi

if [ -d "$APP_PATH" ]; then
    echo "Installing app from: $APP_PATH"
    xcrun simctl install "$DEVICE_UDID" "$APP_PATH" 2>/dev/null || true
else
    echo "Error: Could not find Runner.app at $APP_PATH after build."
    exit 1
fi

# Function to run screenshots in a specific mode
run_flow() {
    local MODE="$1"
    local PREFIX="$2"
    local FLOW_FILE="$3"

    echo ""
    echo "--- $MODE Mode ---"

    # Kill app if running
    xcrun simctl terminate "$DEVICE_UDID" "$APP_ID" 2>/dev/null || true

    if [ "$MODE" = "light" ] || [ "$MODE" = "dark" ]; then
        # Set appearance
        xcrun simctl ui "$DEVICE_UDID" appearance "$MODE"
        sleep 2
    fi

    # Clear previous local screenshots
    rm -f "$SCRIPT_DIR"/*.png

    # Run Maestro
    cd "$SCRIPT_DIR"
    maestro --device "$DEVICE_UDID" test "$FLOW_FILE" || true

    # Collect screenshots
    collect_screenshots "$PREFIX"
}

# Run based on filter
if [ "$MODE_FILTER" = "mixed" ]; then
    run_flow "dark" "dark" "screenshots_dark.yaml"
    run_flow "light" "light" "screenshots_light.yaml"
fi

if [ "$MODE_FILTER" = "light" ] || [ "$MODE_FILTER" = "all" ]; then
    run_flow "light" "light" "screenshots.yaml"
fi

if [ "$MODE_FILTER" = "dark" ] || [ "$MODE_FILTER" = "all" ]; then
    run_flow "dark" "dark" "screenshots.yaml"
fi

# Reset to light mode
xcrun simctl ui "$DEVICE_UDID" appearance light

echo ""
echo "========================================"
echo "Done! Screenshots saved to:"
echo "$OUTPUT_DIR"
echo "========================================"
echo ""
ls -la "$OUTPUT_DIR" 2>/dev/null || echo "No screenshots found"
