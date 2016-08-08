#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-dhewm3.sh
# Script Ver:	0.1.1
# Description:	Game install template
#
# See: 		https://github.com/dhewm/dhewm3/wiki/FAQ
#
# Usage:	./install-dhewm3.sh
# -------------------------------------------------------------------------------

set_vars()
{
	# Set data dir
	# Data files can also be placed in the savegame folder per the FAQ
	# This will be preferred since  / is small on SteamOS

	# config files: $XDG_CONFIG_HOME/GAME (default: $HOME/.config/dhewm3)
	# savegames: $XDG_DATA_HOME/GAME (default: $HOME/.local/share/dhewm3)

	GAME="GAME NAME"
	GAME_DATA="/home/steam/.local/share/${GAME}/base"
	GAME_DATA_ALT="/home/steam/${GAME}"
	CLIENT_PKGS="pkg1 pkg2"
	STEAM_APP_ID="STEAM APP ID"
	PLATFORM="windows or linux etc."
	STEAM_DATA_FILES="$HOME/steamcmd/${GAME}"
	CLEANUP_STEAM_FILES="yes"
	EXTS="pk4
	
	
}

install_client()
{

	echo -e "\n==> Installing dhewm3 package\n"
	sleep 2s

	sources_check_jessie=$(sudo find /etc/apt -type f -name "jessie*.list")
        sources_check_steamos_tools=$(sudo find /etc/apt -type f -name "steamos-tools.list")

        if [[ "$sources_check_jessie" == "" || "$sources_check_steamos_tools" == "" ]]; then

                echo -e " \nDebian/LibreGeek sources do not appear to be installed. Please \
		run './configure-repos.sh' from the main SteamOS-Tools directory\n"
		sleep 2s
		exit 1

        fi

	sudo apt-get install -y --force-yes ${CLIENT_PKGS}

}

game_data_cdrom()
{

	#? CDROM (Does SteamOS automount in desktop mode / SSH?)

	# set disc var
	disc_num=1

	# notice
	echo -e "NOTE: After inserting each disc, allow a few seconds for it to be read"

	while [[ ${disc_num} -gt 0 ]];
	do

		echo -e "\nPlease insert disc ${disc_num} and press enter"
		read -erp "" FAKE_ENTER

		# Umount any disc that may be left over
		sudo umount /dev/sr0 2> /dev/null

		# mout disc and get files
		mkdir -p /tmp/GAME_DATA_TEMP
		sudo mount -t iso9660 -o ro /dev/sr0 /tmp/GAME_DATA_TEMP
		find /tmp/GAME_DATA_TEMP -iname "*.${EXTS}" -exec sudo cp -v {} "${GAME_DATA}" \;
		sudo umount /tmp/GAME_DATA_TEMP

		# See if this is the last disc
		echo -e "\nIs this the last disc you have? [y/n]"
		sleep 0.2s
		read -erp "Choice: " disc_end

		if [[ "${disc_end}" == "n" ]]; then
			disc_num=$((disc_num + 1))

		else
			disc_num=0
		fi

	done

	# ensure we have the patched files
	patch_game

}

game_data_steam()
{

	if [[ ! -f "$HOME/steamcmd/steamcmd.sh" ]]; then

		# install steamcmd
		echo -e "\n==> Installing steamcmd\n"
		mkdir -p "$HOME/steamcmd"
		sudo apt-get install -y lib32gcc1 
		wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -q -nc --show-progress
		sudo tar -xf "steamcmd_linux.tar.gz" -C "$HOME/steamcmd"
		rm -f "steamcmd_linux.tar.gz"

	fi

	# get Doom3 files via steam (you must own the game!)
	echo -e "\n==> Acquiring files via Steam. You must own the game!"
	read -erp "    Steam username: " STEAM_LOGIN_NAME
	echo ""

	# Download
	# steam cmd likes to put the files in the same directory as the script
	
	mkdir -p ${STEAM_DATA_FILES}
	${HOME}/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType ${PLATFORM} +login ${STEAM_LOGIN_NAME} \
	+force_install_dir ./${GAME}/ +app_update ${STEAM_APP_ID} validate +quit
	
	#find doom3/ -iname "*.pk4" -exec sudo cp -v {} "${GAME_DATA}" \;
	find "${STEAM_DATA_FILES}"-iname "*.pk4" -exec sudo cp -v {} "${GAME_DATA}" \;

	# cleanup
	if [[ "${CLEANUP_STEAM_FILES}" == "yes" ]]; then

		rm -rf "${STEAM_DATA_FILES}"
	
	fi
}

game_data_custom()
{

	# CUSTOM
	# ask for folder
	echo -e "\nPlease enter the path to the game files (must contain any patched files!)"
	sleep 0.2s
	read -erp "Location: " custom_file_loc

	# copy files
	find "${custom_file_loc}" -iname "*.${EXTS}" -exec sudo cp -v {} "${GAME_DATA}" \;

}

patch_game()
{
	# ensure we have the patched files

	echo -e "\n==> Gathering updated patch files\n"

	sleep 2s
	wget "http://libregeek.org/SteamOS-Extra/games/doom3/doom3-linux-1.3.1.1304.x86.run" -q -nc --show-progress
	chmod +x doom3-linux-1.3.1.1304.x86.run
	sh doom3-linux-1.3.1.1304.x86.run --tar xvf --wildcards base/pak* d3xp/pak*
	find . -iname "*.pk4" -exec sudo cp -v {} "${GAME_DATA}" \;

	# cleanup
	rm -rf base d3xp doom3-linux*.run

}

install_data_files()
{

	echo -e "\n==> Checking existance of data directory\n"

	if [[ ! -d "${GAME_DATA}" ]]; then

		sudo mkdir -p "${GAME_DATA}"
		sudo chown -R steam:steam "${GAME_DATA}"

	fi

	# the prompt sometimes likes to jump above sleep
	cat<<- EOF
	==============================================
	Installing Data files for ${GAME}
	==============================================
	Please choose a source:

	1) CD-ROM / DVD-ROM
	2) Steam game files (downloads via steamcmd)
	3) Custom location

	EOF

	sleep 0.5s

	read -erp "Choice: " install_choice

	case "${install_choice}" in

		1)
		game_data_cdrom
		;;

		2)
		game_data_steam
		;;

		3)
		game_data_custom
		;;

		*)
		echo "Invalid selection!"
		sleep 1s
		continue
		;;

	esac

}

post_install()
{

	echo -e "\n==> Copying post install configuration files\n"

	# Fix perms
	sudo chmod 755 -R "${GAME_DATA}"

	# copy dekstop file
	sudo cp ../cfgs/desktop-files/${GAME}.desktop "/usr/share/applications"

	# Get artwork
	sudo wget -O "/usr/share/pixmaps/${GAME}.png" "http://cdn.akamai.steamstatic.com/steam/apps/${STEAM_APP_ID}/header.jpg" -q

}

# main script
set_vars || exit 1
install_client || exit 1
install_data_files || exit 1
post_install || exit 1
