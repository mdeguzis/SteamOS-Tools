#!/bin/bash

# 1. Detect the correct kdeconnectd path
KDE_PATH=$(find /usr -name kdeconnectd 2>/dev/null | head -n 1)

if [ -z "$KDE_PATH" ]; then
    echo "Error: kdeconnectd binary not found. Is it installed?"
    exit 1
fi

echo "Found kdeconnectd at: $KDE_PATH"

# 2. Create the systemd user directory
mkdir -p ~/.config/systemd/user/

# 3. Create the service file
cat <<EOF > ~/.config/systemd/user/kdeconnectd.service
[Unit]
Description=KDE Connect Daemon
After=graphical-session.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/$UID
ExecStartPre=/usr/bin/sleep 5
ExecStart=$KDE_PATH
Restart=on-failure
RestartSec=10

[Install]
WantedBy=graphical-session.target
EOF

echo "Systemd service file created/updated."

# 4. Configure Firewall
echo "Configuring firewall (requires sudo)..."
sudo firewall-cmd --permanent --add-service=kdeconnect
sudo firewall-cmd --reload

# 5. Reload and Start Service
echo "Starting KDE Connect service..."
systemctl --user daemon-reload
systemctl --user enable --now kdeconnectd.service

# 6. Final Status Check
echo "-----------------------------------------------"
systemctl --user status kdeconnectd.service --no-pager
echo "-----------------------------------------------"
echo "If 'Active: active (running)', your phone should now see Bazzite."
echo "Running network refresh..."
kdeconnect-cli --refresh

