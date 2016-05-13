#!/bin/bash
# Date : (2016-05-13 09:29)
# Last revision : (2016-05-13 09:29)
# Wine version used : 1.9.8 (64 bit prefix)
# Distribution used to test : SteamOS / Debian 8.4 Jessie
# Author : ProfessorKaos64
# Only For : http://www.playonlinux.com
# SteamDB: https://steamdb.info/app/379720/

#############################################################
# Legacy notes:
#############################################################
# Script based off of : https://www.playonlinux.com/en/app-984-Rage.html
# Feel free to submit improvements!

[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"
 
TITLE="DOOM"
PREFIX="doom4"
EDITOR="ID Software"
GAME_URL="http://doom.com"
AUTHOR="ProfessorKaos64"
WORKING_WINE_VERSION="1.9.8"
GAME_VMS="1024"
STEAM_ID="379720"
 
# Starting the script
POL_GetSetupImages "http://cdn.akamai.steamstatic.com/steam/apps/379720/header.jpg" "$TITLE"
POL_SetupWindow_Init
 
# Starting debugging API
POL_Debug_Init
POL_SetupWindow_presentation "$TITLE" "$EDITOR" "$GAME_URL" "$AUTHOR" "$PREFIX"
 
# Setting prefix path
POL_Wine_SelectPrefix "$PREFIX"
 
# Downloading wine if necessary and creating prefix
POL_System_SetArch "amd64" # This game requires a 64 bit prefix
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# Asking about memory size of graphic card
POL_SetupWindow_VMS "$GAME_VMS"

# Fix some installation/game issues
Set_OS "win7"
 
# Installing mandatory dependencies
# Current list based of Steam installer and RAGE installer for now:
# https://www.playonlinux.com/en/app-4-Steam.html

POL_Call POL_Install_steam
POL_Call POL_Install_vcrun2005 # Fix installation issue
POL_Call POL_Install_vcrun2008 # Fix game issue
POL_Call POL_Install_vcrun2010 # Fix multiplayer issue
POL_Call POL_Install_dxfullsetup # Fix game crash

# Asking about memory size of graphic card
POL_SetupWindow_VMS $GAME_VMS

# Fix for this game
# This was included in the script for RAGE, so it may not be needed
cd "$WINEPREFIX/drive_c/windows/temp/"
cat << EOF > Fix.reg
[HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver]
"GrabFullscreen"="Y"
EOF
POL_Wine regedit "Fix.reg"

# Set Graphic Card informations keys for wine
POL_Wine_SetVideoDriver

# Mandatory pre-install fix for steam
POL_Call POL_Install_steam_flags "$STEAM_ID"

# Choose between DVD, Digital Download or STEAM version

# I don't have the install DVD for DOOM, so I'll have to verify that method set later
# If you know the exact names/values, and preferably tested it, let me know!
# Sorry!

#POL_SetupWindow_InstallMethod "DVD,STEAM,LOCAL"
INSTALL_METHOD="STEAM"

# Begin game installation
if [ "$INSTALL_METHOD" == "DVD" ]; then

 #asking for CDROM and checking if it's correct one
 POL_SetupWindow_message "$(eval_gettext 'Please insert game media into your disk drive')" "$TITLE"
 POL_SetupWindow_cdrom
 POL_Wine start /unix "$CDROM/setup.exe"
 POL_Wine_WaitExit "$TITLE"
 POL_Shortcut "DOOMx64.exe" "$TITLE" "" ""

elif [ "$INSTALL_METHOD" == "STEAM" ]; then

 # Steam install
 # Mandatory pre-install fix for steam
 POL_Call POL_Install_steam_flags "$STEAM_ID"
 POL_SetupWindow_message "$(eval_gettext 'When $TITLE download by Steam is finished,\nDo NOT click on Play. \
 \n\nClose COMPLETELY the Steam interface, \nso that the installation script can continue')" "$TITLE"
 cd "$WINEPREFIX/drive_c/$PROGRAMFILES/Steam"
 POL_Wine start /unix "steam.exe" steam://install/$STEAM_ID
 POL_Wine_WaitExit "$TITLE"
 POL_Shortcut "steam.exe" "$TITLE" "$TITLE.png" "steam://rungameid/$STEAM_ID"
 POL_SetupWindow_message "$(eval_gettext 'Do not forget to close Steam when downloading\nis finished, so that \
 $APPLICATION_TITLE can continue\nto install your game.')" "$TITLE"

else

 # Asking then installing DDV of the game
 cd "$HOME"
 POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run:')" "$TITLE"
 SETUP_EXE="$APP_ANSWER"
 POL_Wine start /unix "$SETUP_EXE"
 POL_Wine_WaitExit "$TITLE"
 POL_Shortcut "DOOMx64.exe" "$TITLE" "" ""
        
fi

POL_SetupWindow_Close
exit 0
