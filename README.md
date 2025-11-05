# Chibisafe Watcher

A lightweight, production-ready shell script that monitors a local directory for file changes and automatically uploads new files to a Chibisafe server.

## Features

- 🔍 **Real-time file monitoring** using `fswatch`
- 📤 **Automatic uploads** to Chibisafe with album support
- 🛡️ **Duplicate prevention** - prevents multiple instances from running
- 📝 **Comprehensive logging** with timestamps
- 🔄 **Automatic restart** - runs continuously as a system service
- 💪 **Error handling** - validates configuration and handles edge cases
- 🚀 **Easy to install** - simple setup with launchd service management

## Requirements

### System Requirements
- macOS 10.7+ (for launchd)
- `fswatch` - File system watcher
- `curl` - HTTP client
- Standard POSIX shell utilities

### Installation

Install `fswatch` using Homebrew:

```bash
brew install fswatch
```

Verify installation:

```bash
which fswatch
# Output: /opt/homebrew/bin/fswatch
```

## Quick Start

### 1. Configuration

Create or edit `chibisafe_watcher.env`:

```bash
# Required - Chibisafe server API URL
CHIBISAFE_REQUEST_URL=https://share.example.com/api/upload

# Required - Your Chibisafe API key
CHIBISAFE_API_KEY=your_api_key_here

# Required - Album UUID to upload files to
CHIBISAFE_ALBUM_UUID=25f5e0b7-670e-4907-9bea-27b426928b35

# Required - Local directory to watch
CHIBISAFE_WATCH_DIR=/Users/username/Uploads/

# Optional - Custom log file location (defaults to ./chibisafe_watcher.log)
LOG_FILE=/var/log/chibisafe_watcher.log
```

**Getting your API key and Album UUID:**
1. Log in to your Chibisafe server
2. Go to Settings → API Keys
3. Create a new API key
4. Go to Albums and copy your album's UUID

### 2. Make Script Executable

```bash
chmod +x chibisafe_watcher.sh
chmod +x install_service.sh
chmod +x uninstall_service.sh
```

### 3. Install as System Service (Recommended)

```bash
./install_service.sh
```

This will:
- Install the service in `~/Library/LaunchAgents/`
- Start it automatically
- Configure it to auto-restart if it crashes

## Usage

### Run Manually (for testing)

```bash
./chibisafe_watcher.sh
```

The watcher will start monitoring and log output to both console and log file.

### Control the Service

```bash
# Check service status
launchctl list | grep chibisafe

# Start the service
launchctl start com.chibisafe.watcher

# Stop the service
launchctl stop com.chibisafe.watcher

# Restart the service
launchctl stop com.chibisafe.watcher
launchctl start com.chibisafe.watcher
```

### View Logs

```bash
# Real-time log monitoring
tail -f chibisafe_watcher.log

# View last 50 lines
tail -50 chibisafe_watcher.log

# Search for errors
grep "ERROR" chibisafe_watcher.log

# Search for successful uploads
grep "SUCCESS" chibisafe_watcher.log

# View error logs (service only)
tail -f chibisafe_watcher.error.log
```

### Uninstall Service

```bash
./uninstall_service.sh
```

This will:
- Stop the service
- Remove it from LaunchAgents

## Logging

### Log Levels

- **INFO** - General information (startup, file detection, uploads)
- **SUCCESS** - Successful file uploads
- **WARN** - Warnings (file disappeared, not a regular file)
- **ERROR** - Errors that prevent operation

### Log Format

```
[2025-11-05 15:30:45] INFO: Chibisafe watcher initialized
[2025-11-05 15:30:46] INFO: Watching directory: /Users/lajlev/Uploads/
[2025-11-05 15:30:50] INFO: Detected file change: /Users/lajlev/Uploads/document.pdf
[2025-11-05 15:30:51] INFO: Uploading: /Users/lajlev/Uploads/document.pdf
[2025-11-05 15:30:53] SUCCESS: Uploaded /Users/lajlev/Uploads/document.pdf
```

### Default Log Location

- Console output: stdout/stderr
- File logging: `./chibisafe_watcher.log` (in script directory)
- Service error log: `./chibisafe_watcher.error.log` (when running as service)

To customize log location, add to `chibisafe_watcher.env`:

```bash
LOG_FILE=/path/to/custom/location.log
```

## Testing

### Test the Service

1. **Start the watcher:**
   ```bash
   ./chibisafe_watcher.sh
   ```

2. **In another terminal, add a test file:**
   ```bash
   echo "test content" > /Users/username/Uploads/test.txt
   ```

3. **Watch the logs:**
   ```bash
   tail -f chibisafe_watcher.log
   ```

4. **Verify upload in Chibisafe** - Check your album for the uploaded file

### Simulate Errors

```bash
# Test with invalid API key (watch for upload failures)
# Edit chibisafe_watcher.env with fake credentials

# Test with non-existent directory (watch for startup error)
# Change CHIBISAFE_WATCH_DIR to invalid path

# Test with missing environment variables
# Remove required variables from chibisafe_watcher.env
```

## Troubleshooting

### Service Not Starting

1. **Check the error log:**
   ```bash
   cat chibisafe_watcher.error.log
   ```

2. **Verify configuration:**
   ```bash
   # Test manually
   ./chibisafe_watcher.sh
   ```

3. **Check launchd status:**
   ```bash
   launchctl list com.chibisafe.watcher
   ```

### Service Starting Multiple Times

The script includes duplicate prevention. If multiple instances try to start:

```bash
# Check running processes
ps aux | grep chibisafe_watcher

# Kill all instances
pkill -f chibisafe_watcher.sh

# Clean up PID file
rm chibisafe_watcher.pid

# Restart service
./install_service.sh
```

### Files Not Uploading

1. **Check logs for errors:**
   ```bash
   grep "ERROR" chibisafe_watcher.log
   ```

2. **Verify credentials:**
   ```bash
   # Make test request manually
   curl -H "x-api-key: $CHIBISAFE_API_KEY" \
        -H "albumuuid: $CHIBISAFE_ALBUM_UUID" \
        $CHIBISAFE_REQUEST_URL
   ```

3. **Check file permissions:**
   ```bash
   ls -l /Users/username/Uploads/
   ```

4. **Verify watch directory exists:**
   ```bash
   ls -ld /Users/username/Uploads/
   ```

### High CPU Usage

This can happen if fswatch is watching a directory with many files. Consider:

1. Reducing the scope of the watched directory
2. Excluding certain file types in your file system (if supported)
3. Running on a separate machine with better resources

## Architecture

### Script Components

| Component | Purpose |
|-----------|---------|
| `log_message()` | Centralized logging with timestamps |
| `check_already_running()` | Prevents duplicate instances via PID file |
| `cleanup()` | Graceful shutdown handler |
| `setup_environment()` | Configuration validation and initialization |
| `upload()` | Handles file upload to Chibisafe |
| `start_watch()` | Main file system monitoring loop |

### File Structure

```
chibisafe-uploader/
├── chibisafe_watcher.sh          # Main watcher script
├── chibisafe_watcher.env         # Configuration file
├── com.chibisafe.watcher.plist   # launchd service definition
├── install_service.sh             # Install as system service
├── uninstall_service.sh           # Uninstall service
├── chibisafe_watcher.pid         # Process ID (auto-generated)
├── chibisafe_watcher.log         # Activity log (auto-generated)
└── README.md                      # This file
```

## Security Considerations

### API Key Management

- **Never commit** `chibisafe_watcher.env` to version control
- **Restrict file permissions:**
  ```bash
  chmod 600 chibisafe_watcher.env
  ```
- **Use service-specific API keys** - Create a dedicated key for this script
- **Rotate keys regularly** - Update in `chibisafe_watcher.env` as needed

### File System Security

- **Watch directory permissions** - Ensure only trusted users can write to it
- **Monitor uploads** - Regularly check what's being uploaded in Chibisafe
- **Validate file types** - Consider adding file type validation in the script

### Network Security

- **Use HTTPS** - Always use `https://` for `CHIBISAFE_REQUEST_URL`
- **Monitor logs** - Watch for failed uploads or HTTP errors
- **Rate limiting** - Chibisafe may have rate limits; check server configuration

## Advanced Configuration

### Custom Upload Processing

To add custom logic before uploading, modify the `upload()` function:

```bash
upload() {
    filename=$1
    
    # Add custom processing here
    # Example: convert image format, compress file, validate type, etc.
    
    # Original upload logic follows...
}
```

### Multiple Watch Directories

For multiple directories, create separate instances:

```bash
# Create separate env files
cp chibisafe_watcher.env chibisafe_watcher_photos.env
cp chibisafe_watcher.env chibisafe_watcher_documents.env

# Create separate scripts
cp chibisafe_watcher.sh chibisafe_watcher_photos.sh
cp chibisafe_watcher.sh chibisafe_watcher_documents.sh

# Edit each script to load the corresponding env file
```

### Environment Variable Override

Override environment variables at runtime:

```bash
# Temporarily change watch directory
CHIBISAFE_WATCH_DIR=/tmp/uploads ./chibisafe_watcher.sh
```

## Performance

### Metrics

- **Memory**: ~10-20 MB (varies with system)
- **CPU**: Minimal when idle, spikes during uploads
- **Network**: Depends on file sizes being uploaded
- **Disk I/O**: Minimal, only reads files for upload

### Optimization Tips

1. **Limit watch directory scope** - Don't watch large directories
2. **Use fast storage** - SSD preferred for file system monitoring
3. **Compress files** - Pre-compress before placing in watch directory
4. **Batch uploads** - Chibisafe may handle batch uploads more efficiently

## Contributing & Support

### Reporting Issues

If you encounter issues:

1. Check the logs for error messages
2. Try running manually to see detailed output
3. Verify your configuration with the test commands above

### Debugging

Enable verbose output:

```bash
# Run with set -x for debug output
sh -x chibisafe_watcher.sh
```

## License

[Specify your license here]

## Changelog

### Version 1.0.0 (2025-11-05)

- ✨ Initial release
- ✨ Real-time file monitoring with fswatch
- ✨ Automatic Chibisafe uploads
- ✨ Comprehensive logging
- ✨ Duplicate instance prevention
- ✨ launchd service management
- ✨ Error handling and validation

## Related Resources

- [Chibisafe Documentation](https://chibisafe.app)
- [fswatch Documentation](https://emcrisostomo.github.io/fswatch/)
- [macOS launchd Documentation](https://www.man7.org/linux/man-pages/man5/launchd.plist.5.html)

## FAQ

**Q: Will the watcher automatically restart after a system reboot?**
A: Yes! When installed as a launchd service, it will automatically start at login.

**Q: Can I watch multiple directories?**
A: Yes, create separate instances with different configuration files.

**Q: What happens if the internet connection drops during upload?**
A: The curl command will timeout (default 300 seconds). The file remains in the watch directory and will be retried on next change detection.

**Q: How do I stop the watcher?**
A: Use `launchctl stop com.chibisafe.watcher` or press Ctrl+C when running manually.

**Q: Can I filter which files get uploaded?**
A: Not yet, but you could add file type filtering in the `upload()` function.

**Q: Where can I find my API key in Chibisafe?**
A: Settings → API Keys → Create New Key

---

**Last Updated:** November 5, 2025
