#!/bin/bash
# Installs the update-emulators desktop file for use in/out of 
# SteamOS GameMode / Desktop mode

set -e -o pipefail

GIT_ROOT=$(git rev-parse --show-toplevel)
cp -v "${GIT_ROOT}/cfgs/desktop-files/update-emulators.desktop" "${HOME}/Desktop"
sudo cp -v "${GIT_ROOT}/cfgs/desktop-files/update-emulators.desktop" "/usr/share/applications"
cp -v "${GIT_ROOT}/utilities/update-emulators/update-emulators.sh" "${HOME}/.local/bin"
cp -v "${GIT_ROOT}/utilities/update-emulators/launch-update-emulators.sh" "${HOME}/.local/bin"

echo -e "\nYou can now add this via the Decky Loader > Quick Launch plugin."
echo "'launch-update-emulators.sh' is meant for Steam GameMode"
