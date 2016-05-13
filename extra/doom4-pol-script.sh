#!/bin/bash
# Date : (2016-03-13 09:29)
# Last revision : (2016-03-13 09:29)
# Wine version used : 1.9.8
# Distribution used to test : SteamOS / Debian 8.4 Jessie
# Author : ProfessorKaos64
# Only For : http://www.playonlinux.com
# Script based off of: Wolfenstein - The New Order by z3ke
 
## Note ##
#
# POL_GetSetupImages are currently not available on playonlinux so I decided to remove this from the script
# The game itself has no shortcut icon, please select one after installation
# When you play the game on multiscreen systems you should play in window-mode or you get some strange behaivor
#
# Feel free to submit fixes or improvements
#
## Note ##
 
[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"
 
TITLE="DOOM"
PREFIX="doom4"
EDITOR="Bethesda Softworks"
GAME_URL="http://doom.com"
AUTHOR="ProfessorKaos64"
WORKING_WINE_VERSION="1.9.8"
#GAME_VMS="1024" # ASK FOR THIS
STEAM_ID="379720"
 
# Starting the script

POL_SetupWindow_Init
 
# Starting debugging API

POL_Debug_Init
 
POL_SetupWindow_presentation "$TITLE" "$EDITOR" "$GAME_URL" "$AUTHOR" "$PREFIX"
 
# Setting prefix path

POL_Wine_SelectPrefix "$PREFIX"
 
# Downloading wine if necessary and creating prefix

POL_System_SetArch "amd64"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"

# Asking about memory size of graphic card

POL_SetupWindow_VMS "$GAME_VMS"
 
# Choose between DVD, Digital Download or STEAM version
# I don't have the install DVD for DOOM, so I'll have to verify that method set later
# Sorry!

#POL_SetupWindow_InstallMethod "DVD,STEAM,LOCAL"

INSTALL_METHOD="STEAM"
 
# Installing mandatory dependencies
# Current list based of Steam installer for now:
# https://www.playonlinux.com/en/app-4-Steam.html

#POL_Call POL_Install_vcrun2005
#POL_Call POL_Install_vcrun2008
#POL_Call POL_Install_xinput
#POL_Call POL_Install_xact
#POL_Call POL_Install_dxfullsetup
POL_Wine_InstallFonts
POL_Call POL_Install_corefonts
POL_Function_FontsSmoothRGB
POL_Call POL_Install_steam
 
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
                                 
        POL_SetupWindow_message "$(eval_gettext 'When $TITLE download by Steam is finished,\nDo NOT click on Play.\n\nClose COMPLETELY the Steam interface, \nso that the installation script can continue')" "$TITLE"
        cd "$WINEPREFIX/drive_c/$PROGRAMFILES/Steam"
        POL_Wine start /unix "steam.exe" steam://install/$STEAM_ID
        POL_Wine_WaitExit "$TITLE"
        POL_Shortcut "steam.exe" "$TITLE" "$TITLE.png" "steam://rungameid/$STEAM_ID"
         
else
        # Asking then installing DDV of the game
        cd "$HOME"
        POL_SetupWindow_browse "$(eval_gettext 'Please select the setup file to run:')" "$TITLE"
        SETUP_EXE="$APP_ANSWER"
        POL_Wine start /unix "$SETUP_EXE"
        POL_Wine_WaitExit "$TITLE"
        POL_Shortcut "DOOMx64.exe" "$TITLE" "" ""
fi
 
 
 
## Fix for this game

# Sound problem fix - pulseaudio related
#[ "$POL_OS" = "Linux" ] && Set_SoundDriver "alsa"
#[ "$POL_OS" = "Linux" ] && Set_SoundEmulDriver "Y"
## End Fix
 
# Asking about memory size of graphic card

POL_SetupWindow_VMS $GAME_VMS
 
# Set Graphic Card informations keys for wine

POL_Wine_SetVideoDriver
 
# Information for troubleshooting

#POL_SetupWindow_message "If you have trouble to display the game correctly please\nchange the resolution of the game and maybe play in window-mode\n" "Information"
 
POL_SetupWindow_Close
exit 0
