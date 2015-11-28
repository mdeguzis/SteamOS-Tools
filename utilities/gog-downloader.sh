#!/bin/bash
# -----------------------------------------------------------------------
# Author: 		    Sharkwouter, Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	gog-downloader.sh
# Script Ver:	  	0.1.3
# Description:	  Downloads and install GOG games - IN PROGRESS!!!
#	
# Usage:	      	
# -----------------------------------------------------------------------
# check if password is set
passset=$(passwd -S|cut -f2 -d" ")
if [ passset =! "P" ];then
        if [ $(zenity --question --text="Admin password not set! Do you want to set it now?" && echo 1) ];then
                gnome-terminal -x /bin/bash -c "echo 'Choose an admin password'; until passwd; do echo 'Try again'; done ;"
        else
                zenity --error --text="Admin password has to be set to be able to install GOG games."
                exit 1
        fi
fi

# login to GOG if not done yet
if [ ! -f ~/.config/lgogdownloader/config.cfg ];then
        while [ ! -f ~/.config/lgogdownloader/config.cfg ];do
                gnome-terminal -x /bin/bash -c "echo 'Log in to GOG:'; lgogdownloader --login;"
        done
fi

# select game to download
game=$(zenity --list --column=Games --text="Pick a game from your GOG library to install" `./lgogdownloader --list --platform=4`)

# download game
./lgogdownloader --download --platform=4 --include=1 --game ${game}|zenity --progress --pulsate --no-cancel --auto-close --text="Downloading Installer of ${game}" --title="Downloading Installer"

# run installer
chmod +x ${game}/gog_${game}*.sh
gksudo -u steam -P "Please enter your admin password to install ${game}" ./${game}/gog_${game}*.sh
