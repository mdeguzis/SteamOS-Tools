#!/bin/bash
# Installs the update-software desktop file for use in/out of 
# SteamOS GameMode / Desktop mode

set -e -o pipefail

GIT_ROOT=$(git rev-parse --show-toplevel)
CONFIG_ROOT="${HOME}/.config/steamos-tools"

# Config dirs
mkdir -p "${CONFIG_ROOT}"
mkdir -p "${CONFIG_ROOT}/ludusavi"

# Copy
cp -v "${GIT_ROOT}/cfgs/ludusavi/config.yaml" "${CONFIG_ROOT}/ludusavi/"
cp -v "${GIT_ROOT}/cfgs/desktop-files/update-software.desktop" "${HOME}/Desktop"
cp -v "${GIT_ROOT}/cfgs/desktop-files/update-software.desktop" "${HOME}/.local/share/applications"
cp -v "${GIT_ROOT}/utilities/update-software/update-software.sh" "${HOME}/.local/bin"
cp -v "${GIT_ROOT}/utilities/update-software/launch-update-software.sh" "${HOME}/.local/bin"

echo -e "\nYou can now add this via the Decky Loader > Quick Launch plugin."
echo "'launch-update-software.sh' is meant for Steam GameMode"

echo -e "\nGamepad controls for menu:"
echo "To use the menu with a gamepad, use the 'Keyboard and mouse' controller profile"
