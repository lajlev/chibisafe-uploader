#!/bin/bash

set -e  # Exit on error

echo "🔨 Building Chibisafe Uploader..."

# Clean previous builds
echo "📦 Cleaning previous builds..."
rm -rf ChibisafeUploader.app

# Build the Swift binary
echo "⚙️  Compiling Swift binary..."
swift build -c release

# Check if binary was created
if [ ! -f ".build/release/ChibisafeUploader" ]; then
    echo "❌ Error: Binary not found at .build/release/ChibisafeUploader"
    exit 1
fi

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p ChibisafeUploader.app/Contents/MacOS
mkdir -p ChibisafeUploader.app/Contents/Resources

# Copy binary
echo "📋 Copying binary..."
cp .build/release/ChibisafeUploader ChibisafeUploader.app/Contents/MacOS/

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp Info.plist ChibisafeUploader.app/Contents/

# Copy icon if it exists
if [ -f "AppIcon.icns" ]; then
    echo "🎨 Copying app icon..."
    cp AppIcon.icns ChibisafeUploader.app/Contents/Resources/
else
    echo "⚠️  Warning: AppIcon.icns not found, app will use default icon"
fi

# Make binary executable
chmod +x ChibisafeUploader.app/Contents/MacOS/ChibisafeUploader

# Get file sizes
BINARY_SIZE=$(du -h .build/release/ChibisafeUploader | cut -f1)
APP_SIZE=$(du -sh ChibisafeUploader.app | cut -f1)

echo ""
echo "✅ Build complete!"
echo "📊 Binary size: $BINARY_SIZE"
echo "📦 App bundle size: $APP_SIZE"
echo ""
echo "🚀 To run: open ChibisafeUploader.app"
echo "📍 Location: $(pwd)/ChibisafeUploader.app"
