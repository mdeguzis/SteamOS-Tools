#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-steam-game-cli.sh
# Script Ver:	0.8.1
# Description:	Downloads a game from Steam, based on it's AppID, useful for
#               for on-the-go situations, or free-to-play when you can't 
#               load the client.
#
# Usage:	./install-steam-game-cli.sh [AppID] [Platform]
# -------------------------------------------------------------------------------

GAME_APP_ID="$1"
PLATFORM="$2"

# set defaults 

if [[ "${PLATFORM}" == "" ]]; then

        PLATFORM="linux"

fi

main()
{

	if [[ ! -f "$HOME/steamcmd/steamcmd.sh" ]]; then

		# install steamcmd
		echo -e "\n==> Installing steamcmd\n"
		mkdir -p "${HOME}/steamcmd"
		sudo apt-get install -y lib32gcc1 
		wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -q -nc --show-progress
		sudo tar -xf "steamcmd_linux.tar.gz" -C "$HOME/steamcmd"
		rm -f "steamcmd_linux.tar.gz"

	fi

	# get game files via steam (you must own the game!)
	echo -e "\n==> Acquiring files via Steam. You must own the game!"
	read -erp "    Steam username: " STEAM_LOGIN_NAME
	echo ""

	# Download
	# steam cmd likes to put the files in the same directory as the script
	
	echo -e "Use custom install directory?\n"
	read -erp "Choice [y/n]: " CUSTOM_DATA_PATH
	
	if [[ "${CUSTOM_DATA_PATH}" == "y" ]]; then

	        read -erp "Path: " STEAM_DATA_FILES
	        INSTALL_PATH="+force_install_dir ${STEAM_DATA_FILES}"

        else

                # let this be a default
                STEAM_DATA_FILES="default directory"
                INSTALL_PATH=""
      
        fi
	
	echo -e "\nDownloading game files to: ${STEAM_DATA_FILES}"
	sleep 2s

	${HOME}/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType ${PLATFORM} +login ${STEAM_LOGIN_NAME} \
        ${INSTALL_PATH} +app_update ${GAME_APP_ID} validate +quit

}

# main script start
main
