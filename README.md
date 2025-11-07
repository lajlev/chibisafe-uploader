# Chibisafe Uploader - macOS Menubar App

A lightweight macOS menubar app that automatically uploads files to Chibisafe with instant URL sharing.

## Features

- ☁️ **Automatic Uploads** - Drop files in watched folder, get instant uploads
- 📋 **Instant URLs** - Public URLs copied to clipboard automatically
- 📝 **Recent History** - Last 10 uploads in menubar (click to open)
- 🧹 **Auto Cleanup** - Optionally delete old files to save storage
- 🎨 **Native & Light** - ~40MB memory, <1% CPU idle

## Quick Start

```bash
# Install dependencies
brew install fswatch
xcode-select --install

# Clone and build
git clone https://github.com/lajlev/chibisafe-uploader.git
cd chibisafe-uploader
./build.sh

# Configure (see below)
nano chibisafe_watcher.env

# Run
open ChibisafeUploader.app
```

## Configuration

Create `chibisafe_watcher.env`:

```bash
CHIBISAFE_REQUEST_URL=https://your-server.com/api/upload
CHIBISAFE_API_KEY=your_api_key_here
CHIBISAFE_ALBUM_UUID=your_album_uuid_here
CHIBISAFE_WATCH_DIR=/Users/yourusername/Uploads

# Optional: Auto-cleanup
CHIBISAFE_CLEANUP_ENABLED=false
CHIBISAFE_CLEANUP_AGE_DAYS=180
```

**Get credentials from your Chibisafe:**
- API Key: Dashboard → Settings → API Keys
- Album UUID: Select album, check URL or settings

**Tips:**
- Create watch directory: `mkdir -p ~/Uploads`
- Screenshot integration: `defaults write com.apple.screencapture location ~/Uploads && killall SystemUIServer`

## Usage

1. Drop files into your watch directory
2. URL automatically copied to clipboard
3. Click menubar ☁️ icon to view recent uploads
4. Click any filename to open its URL

## Troubleshooting

**Files not uploading?**
```bash
# Check fswatch is running
ps aux | grep fswatch

# Run with logs visible
./.build/release/ChibisafeUploader
```

**Common fixes:**
- Install fswatch: `brew install fswatch`
- Verify `.env` file exists and paths are correct
- Ensure API key has upload (and admin for cleanup) permissions
- Check watch directory exists

## Auto-start at Login

System Settings → General → Login Items → Add `ChibisafeUploader.app`

## License

MIT

---

**Links:** [Repository](https://github.com/lajlev/chibisafe-uploader) • [Issues](https://github.com/lajlev/chibisafe-uploader/issues) • [Chibisafe](https://chibisafe.moe)
