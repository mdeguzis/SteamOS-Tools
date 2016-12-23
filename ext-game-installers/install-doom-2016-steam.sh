#!/bin/bash
# Installs DOOM 2016 helper scripts
# Pre-requisites: Steam (Windows) and DOOM 2016 installed via POL
# See: https://github.com/mdeguzis/SteamOS-Tools/wiki/Playing-Steam-(Windows)-Games-Using-PlayOnLinux

# A Lutris version of this is planned.

SCRIPTDIR="${PWD}"
GAME="DOOM-2016"
GAME_STEAM_ID="379720"
GAME_EXT="_TODO_"
GAME_STEAMGRID="_TODO"
WORK_DIR="${HOME}/${GAME}-install-tmp"
WINE_PATH="/home/steam/.PlayOnLinux/wine/linux-x86"
WINE_VER="2.0-rc2"
WINE_VARIANT="staging"

mkdir "${WORK_DIR}"
cd "${WORK_DIR}" || exit 1

# Put up disclaimer

cat<<-EOF

----------------------------------------------
Installer helper for DOOM (2016)
----------------------------------------------

Please ensure you have PlayOnLiux properly setup per:
https://github.com/mdeguzis/SteamOS-Tools/wiki/Playing-Steam-(Windows)-Games-Using-PlayOnLinux

Exit now if you have not done so!
"Press Enter to continue or enter 'quit' to exit now"

EOF

read -erp "Choice: " PRESS_START_TO_CONTINUE

if [[ "${PRESS_START_TO_CONTINUE}" == "quit" ]]; then

	exit 1

fi

# Check for the wine staging verison first

if [[ ! -f "${WINE_PATH}/wine-${WINE_VER}-${WINE_VARIANT}" ]]; then

	echo -e "\nERROR: Please install wine-${WINE_VER}-${WINE_VARIANT} via PlayOnLinux first\n"
	exit 1

fi

# Check for Steam (Windows)

if [[ ! -d "/home/steam/.PlayOnLinux/wineprefix/Steam" ]]; then

	echo -e "\nERROR: Please install Steam (Windows) via PlayOnLinux first\n"
	exit 1

fi

# Check for DOOM data files - TODO

if [[ ! -d "/home/steam/.PlayOnLinux/wineprefix/Steam/PATH-TO-DOOM" ]]; then

	echo -e "\nERROR: Please install DOOM (Windows) via PlayOnLinux first\n"
	exit 1

fi

# Copy skeleton files

sudo cp SteamOS-Tools/cfgs/wine/Default.desktop /usr/share/applications/${GAME}.desktop
sudo cp ../cfgs/wine/pol-game-launcher.skel /usr/bin/${GAME}
sudo nano /usr/bin/${GAME}
sudo chmod +x /usr/bin/${GAME}

# Change variables for game

sudo sed -i "s|VERSION_TMP|$WINE_VER|g" "/usr/bin/${GAME}"
sudo sed -i "s|GAME_ID|$GAME_STEAM_ID|g" "/usr/bin/${GAME}"
sudo sed -i "s|GAME_EXE|$GAME_STEAM_ID|g" "/usr/bin/${GAME}"
sudo sed -i "s|Name.*|Name=DOOM|g" "/usr/share/applications/${GAME}.desktop"
sudo sed -i "s|Exec.*|Exec=/usr/bin/${GAME}|g" "/usr/share/applications/${GAME}.desktop"
sudo sed -i "s|Icon.*|Exec=/usr/share/pixmaps/Icon=${GAME_STEAMGRID}|g" "/usr/share/applications/${GAME}.desktop"

echo -e "\nSetup complete! You can now add ${GAME} via Settings > Add non-Steam shortcut\n"
