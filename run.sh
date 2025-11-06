#!/bin/bash

# Chibisafe Uploader - Easy launcher

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if config exists
if [ ! -f "$SCRIPT_DIR/chibisafe_watcher.env" ]; then
    echo "❌ Error: chibisafe_watcher.env not found"
    exit 1
fi

# Check if binary exists
if [ ! -f "$SCRIPT_DIR/.build/release/ChibisafeUploader" ]; then
    echo "📦 Building app..."
    cd "$SCRIPT_DIR"
    swift build -c release
    if [ $? -ne 0 ]; then
        echo "❌ Build failed"
        exit 1
    fi
fi

echo "🚀 Starting Chibisafe Uploader..."
echo "   Look for 📤 in your menubar (top-right)"
echo "   Press Ctrl+C to stop"
echo ""

# Run the app
"$SCRIPT_DIR/.build/release/ChibisafeUploader"
