# Chibisafe Uploader - macOS Menubar App

A lightweight macOS menubar app that monitors a directory and automatically uploads files to Chibisafe with clipboard URL copying, visual notifications, and smart file management.

## Features

- ☁️ **Smart Uploads** - Real-time file monitoring with automatic uploads
- 📋 **Instant Sharing** - URLs automatically copied to clipboard
- 📝 **Recent History** - Last 10 uploads accessible from menubar (click to open)
- 🔗 **Visual Feedback** - Icon changes to 🔗 on successful upload
- 🧹 **Auto Cleanup** - Automatically remove old files to save storage
- 🚫 **Smart Filtering** - Ignores .DS_Store and system files
- 🎨 **Native macOS** - Beautiful cloud emoji icon, minimal resource usage

## Screenshots

**Menubar Menu:**
```
☁️ Chibisafe Uploader
├── Open Dashboard
├── ──────────────
├── Recent Uploads
│   ├──   screenshot.png (click to open URL)
│   ├──   document.pdf
│   └──   ... (up to 10 recent files)
├── ──────────────
├── Status: Watching
├── Clean Old Files Now
└── Quit
```

## Requirements

- **macOS** 10.15 (Catalina) or later
- **Xcode Command Line Tools** (includes Swift compiler)
- **fswatch** - File system monitoring tool
- **Chibisafe Server** - Your own instance with API access

## Installation

### Step 1: Install Prerequisites

```bash
# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Install fswatch using Homebrew
brew install fswatch
```

### Step 2: Clone the Repository

```bash
git clone https://github.com/lajlev/chibisafe-uploader.git
cd chibisafe-uploader
```

### Step 3: Get Your Chibisafe Credentials

You'll need these from your Chibisafe server:

1. **Server URL** - Your Chibisafe instance URL (e.g., `https://share.example.com`)
2. **API Key** - Generate one from: Dashboard → Settings → API Keys
3. **Album UUID** - Create/select an album, find UUID in URL or album settings
4. **Watch Directory** - Local folder to monitor (e.g., `~/Desktop/Uploads`)

### Step 4: Configure the App

Create `chibisafe_watcher.env` in the project directory:

```bash
# Required: Your Chibisafe server settings
CHIBISAFE_REQUEST_URL=https://your-server.com/api/upload
CHIBISAFE_API_KEY=your_api_key_here
CHIBISAFE_ALBUM_UUID=your_album_uuid_here
CHIBISAFE_WATCH_DIR=/Users/yourusername/Desktop/Uploads

# Optional: Auto-cleanup old files (saves storage)
CHIBISAFE_CLEANUP_ENABLED=false
CHIBISAFE_CLEANUP_AGE_DAYS=180
```

**Configuration Reference:**

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `CHIBISAFE_REQUEST_URL` | ✅ Yes | Upload API endpoint | `https://share.example.com/api/upload` |
| `CHIBISAFE_API_KEY` | ✅ Yes | Your API key (needs admin for cleanup) | `abc123xyz...` |
| `CHIBISAFE_ALBUM_UUID` | ✅ Yes | Album UUID for uploads | `a1b2c3d4-...` |
| `CHIBISAFE_WATCH_DIR` | ✅ Yes | Directory to monitor (must exist) | `/Users/john/Uploads` |
| `CHIBISAFE_CLEANUP_ENABLED` | ❌ No | Auto-delete old files (true/false) | `false` |
| `CHIBISAFE_CLEANUP_AGE_DAYS` | ❌ No | Days before deletion (if enabled) | `180` |

**Important:** 
- Replace `yourusername` with your actual macOS username
- Create the watch directory if it doesn't exist: `mkdir -p ~/Desktop/Uploads`
- Keep the `.env` file secure - it contains your API key!

### Step 5: Build the App

Use the build script:

```bash
./build.sh
```

This will:
- Compile the Swift code
- Create the app bundle
- Copy the icon and resources
- Display build statistics

Expected output:
```
✅ Build complete!
📊 Binary size: 220K
📦 App bundle size: 844K
```

### Step 6: Run the App

```bash
open ChibisafeUploader.app
```

The app will start monitoring your watch directory. Look for the ☁️ icon in your menubar!

## How It Works

1. File appears in watch directory
2. fswatch detects the change
3. App uploads file to Chibisafe with correct MIME type
4. Public URL is extracted from response
5. URL is automatically copied to clipboard
6. Menubar icon changes to 🔗 for 600ms

## Usage

### Uploading Files

Simply drag, copy, or save files to your configured watch directory. The app will:

1. 📁 Detect the new file instantly
2. ⬆️ Upload it to your Chibisafe server
3. 📋 Copy the public URL to your clipboard
4. 🔗 Show visual feedback (icon blinks)
5. 💾 Add to recent uploads list

**Supported:** Images, videos, documents, archives - any file type!

## Advanced Configuration

### Auto-start at Login

To launch the app automatically when you log in:

1. Open **System Settings** → **General** → **Login Items**
2. Click the **"+"** button
3. Navigate to and select `ChibisafeUploader.app`
4. Click **"Add"**

The app will now start automatically on login!


### Combine with macOS screenshot settings:
```bash
# Save screenshots directly to watch directory
defaults write com.apple.screencapture location ~/Uploads
killall SystemUIServer
```

### Customization

Want to personalize the app? Edit `Sources/main.swift`:

**Change menubar icon:**
```swift
button.title = "☁️"  // Line ~16 - Use any emoji!
```

**Change upload feedback icon:**
```swift
button.title = "🔗"  // In blinkMenubarIcon() - Customize the blink icon
```

**Change dashboard URL:**
```swift
URL(string: "https://share.lillefar.com/dashboard")  // Update to your server
```

After making changes, rebuild with `./build.sh`

## Troubleshooting

### Files Not Uploading

**Check the basics:**
```bash
# 1. Verify fswatch is running
ps aux | grep fswatch

# 2. Check configuration
cat chibisafe_watcher.env

# 3. Test file detection
cp ~/Desktop/test.txt /path/to/your/watch/directory/
```

**View detailed logs:**
```bash
# Run the app from terminal to see console output
./.build/release/ChibisafeUploader

# In another terminal, test an upload
echo "test" > ~/Desktop/Uploads/test.txt
```

### Common Issues

| Problem | Solution |
|---------|----------|
| **"fswatch not found"** | Install with `brew install fswatch` |
| **"Configuration Error"** | Check `.env` file exists and has valid values |
| **Files not detected** | Verify watch directory exists and has correct path |
| **Upload fails** | Check API key permissions and server URL |
| **Icon not showing** | Check menubar isn't hidden (System Settings → Control Center) |

### API Key Permissions

For full functionality, your API key needs:
- ✅ **Upload permissions** (required for basic uploads)
- ✅ **Admin permissions** (required for cleanup feature)

Generate a new key: Chibisafe Dashboard → Settings → API Keys → Create

### Getting Help

If you encounter issues:
1. Check the [Issues page](https://github.com/lajlev/chibisafe-uploader/issues)
2. Review your configuration against the examples
3. Test with a simple file (small text file)
4. Check Chibisafe server logs for API errors

## Project Structure

```
chibisafe-uploader/
├── Sources/
│   └── main.swift              # Main application code (~800 lines)
├── ChibisafeUploader.app/      # Built application bundle
│   ├── Contents/
│   │   ├── MacOS/
│   │   │   └── ChibisafeUploader  # Compiled binary
│   │   ├── Resources/
│   │   │   └── AppIcon.icns    # Cloud emoji icon
│   │   └── Info.plist          # App metadata
├── Package.swift               # Swift package configuration
├── Info.plist                  # Template plist
├── AppIcon.icns               # Source app icon
├── build.sh                   # Build automation script
├── chibisafe_watcher.env      # Your configuration (git-ignored)
└── README.md                  # This file
```

## Security Best Practices

🔒 **Protecting Your API Key:**
- The `.env` file is automatically git-ignored
- Set restrictive permissions: `chmod 600 chibisafe_watcher.env`
- Create a dedicated API key for this app
- Rotate keys periodically (every 3-6 months)
- Never commit your `.env` file to version control

🔐 **Network Security:**
- Always use HTTPS for your Chibisafe server
- Consider restricting API key to specific IP ranges (if your server supports it)
- Monitor upload activity in your Chibisafe dashboard

## Performance

The app is designed to be lightweight and efficient:

| Metric | Value |
|--------|-------|
| **Memory Usage** | ~40-50 MB |
| **CPU (Idle)** | <1% |
| **CPU (Uploading)** | 2-5% |
| **Binary Size** | 220 KB |
| **App Bundle** | 844 KB |
| **Startup Time** | <1 second |

**Resource Impact:** Negligible - perfect for running 24/7!

## Contributing

Contributions are welcome! Here's how you can help:

1. 🐛 **Report bugs** - Open an issue with steps to reproduce
2. 💡 **Suggest features** - Share your ideas in the issues
3. 🔧 **Submit PRs** - Fork, improve, and submit pull requests
4. 📖 **Improve docs** - Help make the README clearer

## License

MIT License - feel free to use, modify, and distribute!


## Quick Links

- 📦 **Repository:** [github.com/lajlev/chibisafe-uploader](https://github.com/lajlev/chibisafe-uploader)
- 🐛 **Issues:** [Report a bug](https://github.com/lajlev/chibisafe-uploader/issues)
- 🌐 **Chibisafe:** [chibisafe.moe](https://chibisafe.moe)

---

**Ready to start?**

```bash
git clone https://github.com/lajlev/chibisafe-uploader.git
cd chibisafe-uploader
# Configure your .env file
./build.sh && open ChibisafeUploader.app
```

Enjoy seamless file uploads! ☁️
