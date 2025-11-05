#!/usr/bin/env bash

# Uninstall Chibisafe Watcher service

INSTALL_PATH="${HOME}/Library/LaunchAgents/com.chibisafe.watcher.plist"

if [ -f "${INSTALL_PATH}" ]; then
    echo "Uninstalling Chibisafe Watcher service..."
    launchctl unload "${INSTALL_PATH}"
    rm "${INSTALL_PATH}"
    echo "✓ Service uninstalled"
else
    echo "Service is not installed"
fi
