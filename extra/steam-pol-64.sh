#!/bin/bash
# PlayOnLinux Function
# Date : (2016-05-13 09-03)
# Last revision : (2016-05-13 09-03)
# Author : ProfessorKaos64
# Only For : http://www.playonlinux.com
# Note: Steam is a 32 bit application. This scripts aim is to install
#       Steam into a 64 bit WINE prefix for games like DOOM.

# 
#  WIP SCRIPT !!!!!!!!!!!!!!!!!
#
 
# Setting default path for installers
POL_LoadVar_PROGRAMFILES

TITLE="Steam (64-bit WINE prefix)"
PREFIX="Steam64"
AUTHOR="ProfessorKaos64"
WORKING_WINE_VERSION="1.9.8"

# Setting prefix path
POL_Wine_SelectPrefix "$PREFIX"

# Downloading wine if necessary and creating prefix
POL_System_SetArch "amd64"
POL_Wine_PrefixCreate "$WORKING_WINE_VERSION"
 
# Installing mandatory dependencies
POL_Wine_InstallFonts
POL_Call POL_Install_corefonts
POL_Call POL_Function_FontsSmoothRGB
 
# Fix to prevent Steam from launching without text after update
POL_Wine_OverrideDLL "" "dwrite"
 
# Installing Steam
POL_Download_Resource "http://media.steampowered.com/client/installer/SteamSetup.exe"
cd "$POL_USER_ROOT/ressources/"
POL_SetupWindow_wait "$(eval_gettext 'Please complete the Steam setup wizard.')" "$(eval_gettext '$TITLE - Steam Installation')"
POL_Wine "SteamSetup.exe"
POL_SetupWindow_message "$(eval_gettext 'Log into your Steam account once the update is complete.\n\nClick Next to continue.')" "$TITLE - Steam Update and Login"
 
# Fix for Steam (cause wine crash for many games if enabled) - Empty value = disabled
# Note : semble ne plus être nécéssaire désormais?
POL_Wine_OverrideDLL "" "gameoverlayrenderer"
