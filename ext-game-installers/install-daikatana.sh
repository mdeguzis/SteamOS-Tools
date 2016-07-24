#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-daikatana.sh
# Script Ver:	0.8.1
# Description:	Installs required packages, files for daikatana, and facilitates
#		the install of the game.
#
# See: 		https://bitbucket.org/daikatana13/daikatana
#
# Usage:	./install-daikatana.sh
# -------------------------------------------------------------------------------

set_vars()
{
	# Set data dir
	# Data files can also be placed in the savegame folder per the FAQ
	# This will be preferred since  / is small on SteamOS

	# config files: $XDG_CONFIG_HOME/daikatana (default: $HOME/.config/daikatana)
	# savegames: $XDG_DATA_HOME/daikatana (default: $HOME/.local/share/daikatana)

	GAME="daikatana"
	GAME_DATA="/home/desktop/daikatana"
	LINUX_VER="Daikatana-Linux-2016-07-13"
	# Requires 32 bit pacakges of the below.
	# The SteamOS installation should laready have a 32 bit version of any of the below
	# libgl1-nvidia-glx, libgl1-fglrx-glx, or libgl1-mesa-glx
	CLIENT_PKGS="lgogdownloader innoextract libstdc++6:i386 libopenal1:i386"
	GAME_APP_ID="242980"
	PLATFORM="windows"
	STEAM_DATA_FILES="$HOME/steamcmd/${GAME}"
	CLEANUP_STEAM_FILES="yes"
	FILE_EXTS="pk4"
	
}

install_prereqs()
{

	echo -e "\n==> Installing required package\n"
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

		# get patch
		# TODO

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
		mkdir -p "${HOME}/steamcmd"
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
	
	echo -e "\nDownloading game files to: ${GAME_DATA}"
	sleep 2s
	
	mkdir -p ${GAME_DATA}
	${HOME}/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType ${PLATFORM} +login ${STEAM_LOGIN_NAME} \
	+force_install_dir ${GAME_DATA} +app_update ${GAME_APP_ID} validate +quit


}

game_data_custom()
{

	# CUSTOM
	# ask for folder
	echo -e "\nPlease enter the path to the game files (must contain any patched files!)"
	sleep 0.2s
	read -erp "Location: " custom_file_loc

	# copy files
	find "${custom_file_loc}" -iname "*.${FILE_EXTS}" -exec sudo cp -v {} "${GAME_DATA}" \;

	# Call innoextract
	innoextract
}


game_data_gog()
{

	# The version here is already patched to 1.2
	echo -e "Gathering game files from GOG"

	# A bug prevents use of the secure option with lgogdownloader
	# See: https://github.com/Sude-/lgogdownloader/issues/77

	echo -e "\n==> Downloading Daikatana\n" && sleep 2s
	lgogdownloader --download --game daikatana --directory ${HOME} daikatana --insecure

	# backup config file (couldn not find this?)
	# echo -e "\n==> Backing up current.cfg file"

	echo -e "\n==> Fetching Daikatana 1.3 files" && sleep 2s
	wget -P "${GAME_DATA}" \
	"http://libregeek.org/SteamOS-Extra/games/daikatana/${LINUX_VER}.tar.bz2" -nc -q --show-progress

	# Go to 1.3 setup 
	process_game_data

}

process_game_data()
{

	echo -e "\n==> Extracting Daikatana 1.3 files\n" && sleep 2s
	tar -xjvf "${LINUX_VER}.tar.bz2" -C "${GAME_DATA}"

	echo -e "\n==> Installing Daikatana 1.3 files\n" && sleep 2s
	cd "${GAME_DATA}/${LINUX_VER}"
	./extract_from_gog.sh "${GAME_DATA}/setup_daikatana_2.0.0.3.exe"

	echo -e "\n==> Unpack Daikatana setup\n" && sleep 2s
	innoextract -e "${GAME_DATA}/setup_daikatana_2.0.0.3.exe" -d "${GAME_DATA}"

}

main_menu()
{

	# the prompt sometimes likes to jump above sleep
	cat<<- EOF
	==============================================
	${GAME} installation helper script
	==============================================
	Please choose a source:

	1) CD-ROM / DVD-ROM (disabled for now)
	2) Steam game files (downloads via steamcmd)
	3) GOG (Good Old Games)
	3) Custom location

	EOF

	sleep 0.5s

	read -erp "Choice: " install_choice

	case "${install_choice}" in

		1)
		echo -e "Option disabled. (no CD to test with)"
		break
		;;

		2)
		game_data_steam
		;;
		
		3)
		game_data_gog
		;;

		4)
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
	sudo wget "http://cdn.akamai.steamstatic.com/steam/apps/242980/header.jpg" -O "/usr/share/pixmaps/daikatana.png"

	# Symlink executable
	sudo ln -s "${GAME_DATA}/${LINUX_VER}/daikatana" "/usr/bin/daikatana"

}

# main script
set_vars || exit 1
install_prereqs || exit 1
main_menu || exit 1
post_install || exit 1
