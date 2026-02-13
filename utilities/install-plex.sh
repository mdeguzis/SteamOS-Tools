#!/bin/bash

set -e -o pipefail

# --- Configuration ---
PLEX_CONFIG_DIR="$HOME/.config/plex"
PLEX_MEDIA_DIR="$HOME/plex/plexmedia"
QUADLET_DIR="$HOME/.config/containers/systemd"
QUADLET_FILE="$QUADLET_DIR/plex.container"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Plex installation on Bazzite...${NC}"

# 1. Create Directories
echo "Creating Plex directories..."
mkdir -p "$PLEX_CONFIG_DIR" "$PLEX_MEDIA_DIR" "$QUADLET_DIR"

# 2. Create the Quadlet File
echo "Generating Quadlet configuration..."
cat <<EOF > "$QUADLET_FILE"
[Unit]
Description=Plex Media Server (User Container)
After=network-online.target

[Container]
Image=lscr.io/linuxserver/plex:latest
ContainerName=plex
Environment=PUID=$(id -u) PGID=$(id -g) TZ=Etc/UTC VERSION=docker
Volume=%h/.config/plex:/config:Z
Volume=%h/plex/plexmedia:/data/media:Z
Network=host

[Service]
# Correct location for Restart
Restart=always

[Install]
WantedBy=default.target
EOF

# 3. Reload and Start
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "Starting Plex service..."
# We use 'start' instead of 'enable' because Quadlets are 'auto-enabled'
systemctl --user start plex

# 4. Final Verification
echo "Verifying service status..."
sleep 2
if systemctl --user is-active --quiet plex; then
    echo -e "${GREEN}--------------------------------------------------${NC}"
    echo -e "${GREEN}SUCCESS! Plex is running.${NC}"
    echo -e "Access it at: http://localhost:32400/web"
    echo -e "${GREEN}--------------------------------------------------${NC}"
else
    echo -e "${RED}[ERROR]${NC} Plex failed to start. Check 'journalctl --user -u plex'"
    exit 1
fi
