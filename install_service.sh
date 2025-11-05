#!/usr/bin/env bash

# Install Chibisafe Watcher as a launchd service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_FILE="${SCRIPT_DIR}/com.chibisafe.watcher.plist"
INSTALL_PATH="${HOME}/Library/LaunchAgents/com.chibisafe.watcher.plist"

echo "Installing Chibisafe Watcher service..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "${HOME}/Library/LaunchAgents"

# Copy plist file
cp "${PLIST_FILE}" "${INSTALL_PATH}"

# Load the service
launchctl unload "${INSTALL_PATH}" 2>/dev/null || true
launchctl load "${INSTALL_PATH}"

echo "✓ Service installed and started"
echo ""
echo "Useful commands:"
echo "  Start:   launchctl start com.chibisafe.watcher"
echo "  Stop:    launchctl stop com.chibisafe.watcher"
echo "  Status:  launchctl list | grep chibisafe"
echo "  Logs:    tail -f ${SCRIPT_DIR}/chibisafe_watcher.log"
echo "  Errors:  tail -f ${SCRIPT_DIR}/chibisafe_watcher.error.log"
echo ""
echo "To uninstall:"
echo "  launchctl unload ${INSTALL_PATH}"
echo "  rm ${INSTALL_PATH}"
