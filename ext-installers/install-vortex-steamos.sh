#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
REPO="Nexus-Mods/Vortex"
INSTALL_DIR="${HOME}/.vortex-linux"
DOWNLOAD_DIR="${HOME}/Downloads"
DESKTOP_FILE="${HOME}/.local/share/applications/vortex.desktop"
CLI_BIN="${HOME}/.local/bin/vortex"
INCLUDE_PRERELEASE=true
WINEPREFIX="${INSTALL_DIR}/pfx"
TARGET_APP_DIR="${WINEPREFIX}/drive_c/Program Files/Black Tree Gaming Ltd/Vortex"

# --- INSTALLATION OVERWRITE GUARD ---
REINSTALL=false
for arg in "$@"; do
    if [ "$arg" = "--reinstall" ]; then
        REINSTALL=true
    fi
done

if [ -d "$WINEPREFIX" ] && [ "$REINSTALL" = false ]; then
    echo "================================================================="
    echo " ⚠️  Vortex Proton Prefix already exists at:"
    echo "    $WINEPREFIX"
    echo "================================================================="
    echo " To avoid wiping your settings or mods, the installer has stopped."
    echo ""
    echo " If you want to force a clean reinstallation, run:"
    echo "    bash $(basename "$0") --reinstall"
    echo "================================================================="
    exit 0
fi

# If forcing a reinstall, safely clear the old structure first
if [ "$REINSTALL" = true ] && [ -d "$WINEPREFIX" ]; then
    echo "♻️ --reinstall flag detected. Safely clearing old environment..."
    rm -rf "$WINEPREFIX"
    rm -rf "${INSTALL_DIR}/tmp"
fi

echo -e "\n==> Fetching latest Vortex release info...\n"

if [ "$INCLUDE_PRERELEASE" = true ]; then
    API_URL="https://api.github.com/repos/${REPO}/releases"
    RELEASE_DATA=$(curl -s "$API_URL" | jq -r '.[0]')
    TAG_NAME=$(echo "$RELEASE_DATA" | jq -r '.tag_name')
else
    API_URL="https://api.github.com/repos/${REPO}/releases/latest"
    RELEASE_DATA=$(curl -s "$API_URL")
    TAG_NAME=$(echo "$RELEASE_DATA" | jq -r '.tag_name')
fi

VERSION="${TAG_NAME#v}"
DOWNLOAD_URL=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | endswith(".exe")) | .browser_download_url' | head -n 1)
FILENAME=$(basename "$DOWNLOAD_URL")

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
    echo "Error: Could not resolve the .exe download URL."
    exit 1
fi

# --- DOWNLOAD ---
mkdir -p "$DOWNLOAD_DIR"
if [ ! -f "$DOWNLOAD_DIR/$FILENAME" ]; then
    echo "Downloading $FILENAME..."
    curl -L -o "$DOWNLOAD_DIR/$FILENAME" "$DOWNLOAD_URL"
fi

# --- HEADLESS EXTRACTION ---
mkdir -p "$INSTALL_DIR"

echo -e "\n==> Extracting installer payload via CLI...\n"
mkdir -p "$TARGET_APP_DIR"
rm -rf "${INSTALL_DIR}/tmp"

# --- FORCE PROTON PREFIX INITIALIZATION ---
echo -e "\n==> Initializing Proton Prefix via UMU...     "
export WINEPREFIX="${INSTALL_DIR}/pfx"
export GAMEID="umu-vortex"

# Run a headless windows command string to force umu to build out drive_c safely
umu-run c:\\windows\\system32\\cmd.exe /c "echo Prefix Init" > /dev/null 2>&1

# Give the file system a brief split-second to stabilize the layout
sleep 2

# Clean extraction targets
mkdir -p "$TARGET_APP_DIR"
rm -rf "${INSTALL_DIR}/tmp"

echo "Unpacking outer installer container..."
7z x -y -o"${INSTALL_DIR}/tmp" "$DOWNLOAD_DIR/$FILENAME" > /dev/null

# Check if this is the new NSIS layout with a nested archive
NESTED_ARCHIVE="${INSTALL_DIR}/tmp/\$PLUGINSDIR/app-64.7z"

if [ -f "$NESTED_ARCHIVE" ]; then
    echo "Found nested app payload. Unpacking core application files..."
    7z x -y -o"$TARGET_APP_DIR" "$NESTED_ARCHIVE" > /dev/null
else
    # Fallback for older/standard layouts if app-64.7z isn't present
    RAW_FIND=$(find "${INSTALL_DIR}/tmp" -type f -iname "Vortex.exe" | head -n 1)
    if [ -z "$RAW_FIND" ]; then
        echo "❌ ERROR: Could not find Vortex application payload or app-64.7z."
        exit 1
    fi
    FOUND_APP_DIR=$(dirname "$RAW_FIND")
    mv "$FOUND_APP_DIR"/* "$TARGET_APP_DIR/"
fi

# OPTIONAL EXTRACTION: Use the .NET runtime bundled right inside the installer!
BUNDLED_DOTNET="${INSTALL_DIR}/tmp/\$TEMP/windowsdesktop-runtime-win-x64.exe"
DOTNET_TARGET_DIR="${WINEPREFIX}/drive_c/Program Files/dotnet"

if [ -f "$BUNDLED_DOTNET" ]; then
    echo "Found bundled .NET installer! Unpacking dependencies headlessly..."
    mkdir -p "$DOTNET_TARGET_DIR"
    7z x -y -o"$DOTNET_TARGET_DIR" "$BUNDLED_DOTNET" > /dev/null
fi

# Cleanup staging ground safely
rm -rf "${INSTALL_DIR}/tmp"

echo "==========================================="
echo " Verifying Extracted File Paths...         "
echo "==========================================="
if [ -f "$TARGET_APP_DIR/Vortex.exe" ]; then
    echo "✓ Success: Vortex.exe found exactly at: $TARGET_APP_DIR/Vortex.exe"
else
    echo "❌ ERROR: Vortex.exe missing after nested extraction pass!"
    exit 1
fi

rm -rf "${INSTALL_DIR}/tmp"

# --- PREREQUISITE INSTALLATION (.NET DESKTOP RUNTIME FOR VORTEX) ---
echo "==========================================="
echo " Fetching .NET Desktop Runtime 6.0 Binaries "
echo "==========================================="

# Use Microsoft's smart permanent shortcut engine for the Windows x64 Desktop Runtime zip archive
DOTNET_URL="https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.zip"
DOTNET_ZIP="windowsdesktop-runtime-6.0.36-win-x64.zip"
DOTNET_TARGET_DIR="${WINEPREFIX}/drive_c/Program Files/dotnet"

# Clear any corrupted file relics left behind by failed loops
if [ -f "$DOWNLOAD_DIR/$DOTNET_ZIP" ] && [ $(stat -c%s "$DOWNLOAD_DIR/$DOTNET_ZIP") -lt 10000 ]; then
    rm -f "$DOWNLOAD_DIR/$DOTNET_ZIP"
fi

if [ ! -f "$DOWNLOAD_DIR/$DOTNET_ZIP" ]; then
    echo "Downloading .NET Binaries..."
    # Following redirects explicitly (-L) is critical for aka.ms links to hand off to the active CDN mirror
    curl -L -A "Mozilla/5.0 (X11; Linux x86_64)" -o "$DOWNLOAD_DIR/$DOTNET_ZIP" "$DOTNET_URL"
fi

# Double check that we actually grabbed a real archive payload this time (~50+ MB)
if [ $(stat -c%s "$DOWNLOAD_DIR/$DOTNET_ZIP") -lt 100000 ]; then
    echo "Error: Download failed. URL payload returned an invalid size constraint token."
    rm -f "$DOWNLOAD_DIR/$DOTNET_ZIP"
    exit 1
fi

echo "Unpacking .NET framework layers directly into target structure..."
mkdir -p "$DOTNET_TARGET_DIR"
7z x -y -o"$DOTNET_TARGET_DIR" "$DOWNLOAD_DIR/$DOTNET_ZIP" > /dev/null

echo ".NET runtime injection pass complete."

# --- AUTOMATED STEAM LIBRARY DRIVE MAPPING ---
DOSDEVICES_DIR="${WINEPREFIX}/dosdevices"
mkdir -p "$DOSDEVICES_DIR"

INTERNAL_STEAM="$HOME/.local/share/Steam/steamapps/common"
SD_CARD_STEAM="/run/media/mmcblk0p1/steamapps/common"

# Map Drive S: (Internal)
if [ -d "$INTERNAL_STEAM" ]; then
    rm -f "$DOSDEVICES_DIR/s:"
    ln -s "$INTERNAL_STEAM" "$DOSDEVICES_DIR/s:"
fi

# Map Drive M: (SD Card)
if [ -d "$SD_CARD_STEAM" ]; then
    rm -f "$DOSDEVICES_DIR/m:"
    ln -s "$SD_CARD_STEAM" "$DOSDEVICES_DIR/m:"
fi

# --- LOCAL CLI BINARY LAUNCHER CREATION ---
echo -e "\n==> Generating CLI Binary Wrapper...          "
mkdir -p "$(dirname "$CLI_BIN")"

# Internal Windows path mapping that umu-run native environment needs
VORTEX_EXE_PATH="C:\\Program Files\\Black Tree Gaming Ltd\\Vortex\\Vortex.exe"

# --- AUTOMATED STEAM LIBRARY DRIVE MAPPING ---
DOSDEVICES_DIR="${WINEPREFIX}/dosdevices"
mkdir -p "$DOSDEVICES_DIR"

SD_CARD_STEAM="/run/media/mmcblk0p1/steamapps/common"

echo "==========================================="
echo " Configuring Wine Storage Virtual Drives... "
echo "==========================================="
echo "✓ Internal Storage is handled natively by Proton via X:\\"

# Map Drive M: ONLY for the SD Card (Proton won't auto-map this)
if [ -d "$SD_CARD_STEAM" ]; then
    # Ensure clean, lowercase symlink name for Wine compliance
    rm -f "$DOSDEVICES_DIR/m" "$DOSDEVICES_DIR/m:"
    ln -s "$SD_CARD_STEAM" "$DOSDEVICES_DIR/m:"
    
    # Register M: in the Wine registry as a local hard drive
    umu-run reg add "HKCU\\\\Software\\\\Wine\\\\Drives" /v "m" /t REG_SZ /d "hd" /f > /dev/null 2>&1
    echo "✓ Mapped M:\\ -> SD Card Steam Library"
else
    echo "ℹ️ No SD card detected at default SteamOS path. Skipping M: mapping."
fi

# Shortcut for X: or whatever in Vortex to $HOME
ln -sfv "$HOME/.local/share/Steam" "$HOME/Steam"

cat <<EOF > "$CLI_BIN"
#!/usr/bin/env bash
export WINEPREFIX="${WINEPREFIX}"
export GAMEID="umu-vortex"
export DISPLAY="\${DISPLAY:-:0}"
export XAUTHORITY="\${XAUTHORITY:-\${HOME}/.Xauthority}"

# Strip out Proton's global node environment hooks to prevent the Electron security panic
unset NODE_OPTIONS

# --- FORCE WINE VIRTUAL DESKTOP FOR WINDOW MANAGEMENT ---
umu-run reg add "HKCU\\\\Software\\\\Wine\\\\Explorer" /v "Desktop" /t REG_SZ /d "Default" /f > /dev/null 2>&1
umu-run reg add "HKCU\\\\Software\\\\Wine\\\\Explorer\\\\Desktops" /v "Default" /t REG_SZ /d "1920x1080" /f > /dev/null 2>&1

exec umu-run "C:\\\\Program Files\\\\Black Tree Gaming Ltd\\\\Vortex\\\\Vortex.exe" "\$@" --no-sandbox --disable-gpu 2>&1 | tee /tmp/vortex-log.txt
echo 'Log: /tmp/vortex-log.txt'
EOF

chmod +x "$CLI_BIN"
echo "CLI wrapper generated at: $CLI_BIN"

# --- DESKTOP APPLICATION CREATION ---
echo -e "\n==> Generating Desktop Application Launcher... "
echo "==========================================="
mkdir -p "$(dirname "$DESKTOP_FILE")"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Vortex Mod Manager
Comment=Manage mods for games via Proton
Exec="$CLI_BIN" %u
Icon=vortex
Terminal=false
Type=Application
Categories=Game;Utility;
MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

if command -v xdg-mime &> /dev/null; then
    xdg-mime default vortex.desktop x-scheme-handler/nxm
    xdg-mime default vortex.desktop x-scheme-handler/nxm-protocol
fi

if command -v update-mime-database &> /dev/null; then
    update-mime-database ~/.local/share/mime/ || true
fi

echo "==========================================="
echo " Done! You can now test by typing: vortex"
echo " Desktop file: ${DESKTOP_FILE}"
echo " CLI launcher: ${CLI_BIN}"
echo "==========================================="
