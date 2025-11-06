#!/bin/bash

# Debug script - runs the app in terminal to see all output

cd "$(dirname "$0")"

echo "🚀 Starting Chibisafe Uploader with debug output..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
cat chibisafe_watcher.env | grep -v "^#"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watch directory: $(grep CHIBISAFE_WATCH_DIR chibisafe_watcher.env | cut -d= -f2)"
echo ""
echo "All output below is debug info:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

.build/release/ChibisafeUploader
