#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-steam-game-cli.sh
# Script Ver:	0.9.1
# Description:	Downloads a game from Steam, based on it's AppID, useful for
#               for on-the-go situations, or free-to-play when you can't 
#               load the client.
#
# Usage:	./get-steam-game-cli.sh -a [AppID] -p [Platform] -d [TARGET_DIR]
# -------------------------------------------------------------------------------

# source options
while :; do
	case $1 in

		--appid|-a)
			if [[ -n "$2" ]]; then
				GAME_APP_ID=$2
				# echo "INSTALL PATH: $DIRECTORY"
				shift
			else
				echo -e "ERROR: --appid|-a requires an argument.\n" >&2
				exit 1
			fi
		;;

		--directory|-d)       # Takes an option argument, ensuring it has been specified.
			if [[ -n "$2" ]]; then
				CUSTOM_DATA_PATH="true"
				DIRECTORY=$2
				# echo "INSTALL PATH: $DIRECTORY"
				shift
			else
				echo -e "ERROR: --directory|-d requires an argument.\n" >&2
				exit 1
			fi
		;;

		--platform|-p)       # Takes an option argument, ensuring it has been specified.
			if [[ -n "$2" ]]; then
				PLATFORM=$2
				# echo "PLATFORM: $PLATFORM"
				shift
			else
				echo -e "ERROR: --platform|-p requires an argument.\n" >&2
				exit 1
			fi
		;;

		--help|-h) 
			cat<<-EOF
			
			Usage:	 ./get-steam-game-cli.sh [options]
			Options: -a [AppID] 
				 -p [Platform] 
				 -d [TARGET_DIR]
			
			EOF
			break
		;;

		--)
		# End of all options.
		shift
		break
		;;

		-?*)
		printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;

		*)  
		# Default case: If no more options then break out of the loop.
		break

	esac

	# shift args
	shift
done

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

	if [[ "${CUSTOM_DATA_PATH}" != "true" ]]; then

                # let this be a default
                # If this is not set, the path will be $HOME/Steam/steamapps/common/
                STEAM_DATA_FILES="default directory"
                DIRECTORY="/home/steam/.local/share/Steam/steamapps/common/"

        fi

	echo -e "\nDownloading game files to: ${DIRECTORY}"
	sleep 2s

	# run as steam user
	${HOME}/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType \
	${PLATFORM} +login ${STEAM_LOGIN_NAME} +force_install_dir ${DIRECTORY} \
	+app_update ${GAME_APP_ID} validate +quit

}

# main script start
main
