#!/bin/bash
# PlayOnLinux Function
# Date : (2016-05-13 09-03)
# Last revision : (2016-05-13 09-03)
# Author : ProfessorKaos64
# Only For : http://www.playonlinux.com
# Note: Steam is a 32 bit application. This scripts aim is to install
#       Steam into a 64 bit WINE prefix for games like DOOM.
 
[ "$PLAYONLINUX" = "" ] && exit 0
source "$PLAYONLINUX/lib/sources"
 
TITLE="Steam"
WINEVERSION="1.9.8"
GAME_VMS="256"

#starting the script
POL_SetupWindow_Init
POL_SetupWindow_presentation "$TITLE" "Valve" "http://www.valvesoftware.com/" "ProfessorKaos64" "$PREFIX"

# Ask user which prefix they want
POL_SetupWindow_question "Do you want to use a 32 (recommended) of 64 bit WINE prefix?" "WINE Prefx Setup" "32 bit~64 bit" "~"

if [[ "$APP_ANSWER" == "64 bit" ]]; then
	PREFIX_NAME="steam64prefix"
	POL_System_SetArch "amd64"
elif [[ "$APP_ANSWER" == "32 bit" ]]; then
	PREFIX_NAME="steam32prefix"
	POL_System_SetArch "x86"
fi

# If the prefix exists, choose another name
if [ -e "$POL_USER_ROOT/wineprefix/$PREFIX_NAME" ]; then
    POL_SetupWindow_textbox "$(eval_gettext 'Please choose a virtual drive name')" "$TITLE"
    PREFIX="$APP_ANSWER"
else
    PREFIX="$PREFIX_NAME"
fi
 
# Setting prefix path
POL_Wine_SelectPrefix "$PREFIX"
 
# Downloading wine if necessary and creating prefix
POL_Wine_PrefixCreate "$WINEVERSION"
 
# Installing mandatory dependencies
POL_Wine_InstallFonts
POL_Call POL_Install_corefonts
POL_Function_FontsSmoothRGB
POL_Wine_OverrideDLL "" "dwrite"
 
# downloading latest Steam
cd "$POL_USER_ROOT/wineprefix/$PREFIX/drive_c/"
#POL_Download "http://cdn.steampowered.com/download/$STEAM_EXEC" ""
 
# Installing Steam
cd "$POL_USER_ROOT/wineprefix/$PREFIX/drive_c/"
POL_Download "http://media.steampowered.com/client/installer/SteamSetup.exe"
 
POL_Wine_WaitBefore "$TITLE"
POL_Wine "SteamSetup.exe"
 
# Asking about memory size of graphic card
POL_SetupWindow_VMS "$GAME_VMS"
 
## Fix for Steam
# Note : seems not to be necessary now ?
POL_Wine_OverrideDLL "" "gameoverlayrenderer"
## End Fix
 
# Making shortcut
if [[ "$APP_ANSWER" == "64 bit" ]]; then
	POL_Shortcut "Steam.exe" "Steam-64"
elif [[ "$APP_ANSWER" == "32 bit" ]]; then
	POL_Shortcut "Steam.exe" "Steam-32"
fi
 
#POL_SetupWindow_message "$(eval_gettext 'If you encounter problems with some games, try to disable Steam Overlay')" "$TITLE"
 
POL_SetupWindow_message "$(eval_gettext 'If you want to install $TITLE in another virtual drive\nRun this installer again')" "$TITLE"
 
POL_SetupWindow_Close
exit 0
