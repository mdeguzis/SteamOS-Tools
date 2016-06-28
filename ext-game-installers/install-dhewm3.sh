#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-dhewm3.sh
# Script Ver:	0.1.1
# Description:	Installs required packages, files for dhewm3, and facilitates
#		the install of the game.
#
# See: 		https://github.com/dhewm/dhewm3/wiki/FAQ
#
# Usage:	./install-dhewm3.sh
# -------------------------------------------------------------------------------


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

	sudo apt-get install -y --force-yes dhewm3 dhewm3-doom3

}

doom3_data_cdrom()
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
		mkdir -p /tmp/doom3_data
		sudo mount -t iso9660 -o ro /dev/sr0 /tmp/doom3_data
		find /tmp/doom3_data -iname "*.pk4" -exec sudo cp -v {} "${DOOM3_DATA}" \;
		sudo umount /tmp/doom3_data

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

	echo -e "\n==> Gathering updated patch files\n"

	sleep 2s
	wget "http://libregeek.org/SteamOS-Extra/games/doom3/doom3-linux-1.3.1.1304.x86.run" -q -nc --show-progress
	chmod +x doom3-linux-1.3.1.1304.x86.run
	sh doom3-linux-1.3.1.1304.x86.run --tar xvf --wildcards base/pak* d3xp/pak*
	find . -iname "*.pk4" -exec sudo cp -v {} "${DOOM3_DATA}" \;

	# cleanup
	rm -rf base d3xp doom3-linux*.run

}

doom3_data_steam()
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
	mkdir -p doom3
	$HOME/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +login ${STEAM_LOGIN_NAME} \
	+force_install_dir ./doom3/ +app_update 9050 validate +quit

	# Extract .pk4 files
	find doom3/ -iname "*.pk4" -exec sudo cp -v {} "${DOOM3_DATA}" \;

	# cleanup
	rm -rf doom3
}

doom3_data_custom()
{

	# CUSTOM
	# ask for folder
	echo -e "\nPlease enter the path to the .pk4 files (must contain patched files!)"
	sleep 0.2s
	read -erp "Location: " custom_file_loc

	# copy files
	find "${custom_file_loc}" -iname "*.pk4" -exec sudo cp -v {} "${DOOM3_DATA}" \;

}

install_data_files()
{

	echo -e "\n==> Checking existance of data directory\n"

	# Set data dir
	# Data files can also be placed in the savegame folder per the FAQ
	# This will be preferred since  / is small on SteamOS

	# config files: $XDG_CONFIG_HOME/dhewm3 (default: $HOME/.config/dhewm3)
	# savegames: $XDG_DATA_HOME/dhewm3 (default: $HOME/.local/share/dhewm3)

	DOOM3_DATA="/home/steam/.local/share/dhewm3/base"
	DOOM3_DATA_ALT="/home/steam/dhewm3"

	if [[ ! -d "${DOOM3_DATA}" ]]; then

		sudo mkdir -p "${DOOM3_DATA}"
		sudo chown -R steam:steam "${DOOM3_DATA}"


	fi

	# the prompt sometimes likes to jump above sleep
	cat<<- EOF
	==============================================
	Installing Data files for dhewm3
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
		doom3_data_cdrom
		;;

		2)
		doom3_data_steam
		;;

		3)
		doom3_data_custom
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
	sudo chmod 755 -R "${DOOM3_DATA}"

	# copy dekstop file
	sudo cp ../cfgs/desktop-files/dhewm3.desktop "/usr/share/applications"

	# Get artwork
	sudo wget -O "/usr/share/pixmaps/doom3.png" "http://cdn.akamai.steamstatic.com/steam/apps/9050/header.jpg" -q

}

# main script
install_client || exit 1
install_data_files || exit 1
post_install || exit 1
