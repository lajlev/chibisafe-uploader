# Chibisafe Uploader - macOS Menubar App

A lightweight macOS menubar app that monitors a directory and automatically uploads files to Chibisafe with clipboard URL copying and visual notifications.

## Features

- 🔍 Real-time file monitoring using fswatch
- 📤 Automatic uploads to Chibisafe
- 📋 Automatic clipboard URL copying
- 🔗 Visual feedback: icon changes to 🔗 on successful upload
- 🖇️ Click icon to open Chibisafe dashboard
- 🛡️ Duplicate prevention & error handling
- 🧹 Automatic cleanup of old files (configurable)
- 🚫 Filters out .DS_Store files

## Requirements

- macOS 10.15+
- Swift 5.9 (included with Xcode 14+)
- `fswatch`: `brew install fswatch`

## Quick Start

### 1. Install fswatch
```bash
brew install fswatch
```

### 2. Create and Configure
Create & Edit `chibisafe_watcher.env`:
```bash
CHIBISAFE_REQUEST_URL=https://your-server.com/api/upload
CHIBISAFE_API_KEY=your_api_key
CHIBISAFE_ALBUM_UUID=your_album_uuid
CHIBISAFE_WATCH_DIR=/Users/username/Uploads/

# Optional: Auto-cleanup old files
CHIBISAFE_CLEANUP_ENABLED=true
CHIBISAFE_CLEANUP_AGE_DAYS=180
```

**Configuration Options:**
- `CHIBISAFE_REQUEST_URL` - Your Chibisafe upload endpoint
- `CHIBISAFE_API_KEY` - Your API key (must have admin permissions for cleanup)
- `CHIBISAFE_ALBUM_UUID` - Album UUID to upload to
- `CHIBISAFE_WATCH_DIR` - Directory to monitor for new files
- `CHIBISAFE_CLEANUP_ENABLED` - Enable automatic cleanup (true/false, default: false)
- `CHIBISAFE_CLEANUP_AGE_DAYS` - Delete files older than X days (default: 180 = 6 months)

### 3. Build & Run
```bash
swift build -c release
open ChibisafeUploader.app
```

Or use the launcher:
```bash
./run.sh
```

## How It Works

1. File appears in watch directory
2. fswatch detects the change
3. App uploads file to Chibisafe with correct MIME type
4. Public URL is extracted from response
5. URL is automatically copied to clipboard
6. Menubar icon changes to 🔗 for 600ms

## Menubar Menu

Click the ☁️ icon to:
- **Open Dashboard** - Opens your Chibisafe dashboard
- **Status: Watching** - Shows monitoring is active
- **Clean Old Files Now** - Manually trigger cleanup (removes files older than configured age)
- **Auto-cleanup: Enabled/Disabled** - Shows cleanup status and age threshold
- **Quit** - Close the app

## File Cleanup Feature

The app can automatically remove old files from your Chibisafe album to save storage space.

**How it works:**
- Runs daily when auto-cleanup is enabled
- Checks all files in the configured album
- Deletes files older than the configured age threshold (default: 180 days / 6 months)
- Can be triggered manually from the menubar

**Setup:**
1. Enable in `chibisafe_watcher.env`:
   ```bash
   CHIBISAFE_CLEANUP_ENABLED=true
   CHIBISAFE_CLEANUP_AGE_DAYS=180
   ```
2. Ensure your API key has admin permissions
3. Restart the app

**Manual cleanup:**
- Click the menubar icon → "Clean Old Files Now"
- Shows notification with number of files deleted

## Auto-start at Login

1. System Settings → General → Login Items
2. Click "+"
3. Select `ChibisafeUploader.app`
4. Click "Add"

## Customization

### Change Menubar Icon
Edit `Sources/main.swift`:
```swift
button.title = "📤"  // Change to any emoji
```

### Change Link Icon
```swift
button.title = "🔗"  // Edit in blinkMenubarIcon()
```

## Troubleshooting

**Files not uploading?**
```bash
# Run with debug output
./debug.sh

# In another terminal, copy a file
cp ~/Desktop/test.txt /Users/username/Uploads/
```

**Check logs:**
```bash
tail -f app.log
```

**Verify configuration:**
```bash
cat chibisafe_watcher.env
```

## Project Structure

```
├── Sources/main.swift      # Complete Swift app (~500 lines)
├── Package.swift           # Build configuration
├── Info.plist             # App metadata
├── chibisafe_watcher.env  # Configuration (git ignored)
└── ChibisafeUploader.app/  # Built app bundle
```

## Security

- API key in `chibisafe_watcher.env` is git-ignored
- Set permissions: `chmod 600 chibisafe_watcher.env`
- Create a dedicated API key for this app
- Rotate keys periodically

## Performance

- Memory: ~40-50 MB
- CPU: Minimal at idle
- Binary size: 127 KB

## License

MIT

## Version

**1.1.0** - November 2025
- Added automatic cleanup feature for old files
- Added .DS_Store file filtering
- Configurable cleanup age threshold
- Manual cleanup trigger from menubar

**1.0.0** - November 2025
- Initial release

---

**Get started:**
```bash
swift build -c release && open ChibisafeUploader.app
```
