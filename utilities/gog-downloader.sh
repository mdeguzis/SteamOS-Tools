#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	Sharkwouter, Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	gog-downloader.sh
# Script Ver:	0.1.7
# Description:	Downloads and install GOG games - IN PROGRESS!!!
#
# Usage:
# -----------------------------------------------------------------------

# check if password is set
pw_set=$(passwd -S | cut -f2 -d " ")

if [[ "$pw_set" != "P" ]];then

        pw_response=$(zenity --question --title="Set user password" --text="Admin password not set! Do you want to set it now?")

	if [[ "$pw_response" == "Yes" ]]; then

        	ENTRY=`zenity --password`

		case $? in
         	0)
	 		adminpw=$(echo $ENTRY | cut -d'|' -f2)
			;;
         	1)
                	echo "Stop login.";;
        	-1)
                	echo "An unexpected error has occurred.";;
		esac

	else

                zenity --error --text="Admin password has to be set to be able to install GOG games."
                exit 1

        fi
fi

# login to GOG if not done yet
if [[ ! -f "$HOME/.config/lgogdownloader/config.cfg" ]]; then

	while [ ! -f ~/.config/lgogdownloader/config.cfg ];
	do

		ENTRY=`zenity --title="Login to GOG.com" --text="Please login to your GOG.com account" --password --username`

		case $? in
         	0)
         		# IN TESTING
	 		gog_user=$(echo $ENTRY | cut -d'|' -f1)
	 		gog_pw=$(echo $ENTRY | cut -d'|' -f2)
	 		echo $gog_user
	 		echo $gog_pw
	 		exit 1
			;;
         	1)
                	echo "Stop login.";;
        	-1)
                	echo "An unexpected error has occurred.";;
		esac

        done

fi

# select game to download
game=$(zenity --list --column=Games --text="Pick a game from your GOG library to install" `./lgogdownloader --list --platform=4`)

# download game
./lgogdownloader --download --platform=4 --include=1 --game ${game}|zenity --progress --pulsate --no-cancel --auto-close --text="Downloading Installer of ${game}" --title="Downloading Installer"

# run installer
chmod +x ${game}/gog_${game}*.sh
gksudo -u steam -P "Please enter your admin password to install ${game}" ./${game}/gog_${game}*.sh
