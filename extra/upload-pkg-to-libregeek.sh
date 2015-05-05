#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		upload-pkg-to-libregeek.sh
# Script Ver:	  	0.1.1
# Description:		upload completed deb packages to libregeek.org
#
# Usage:          ./upload-pkg-to-libregeek.sh [pkg name]
# -------------------------------------------------------------------------------

TYPE="$1"
PKG="$2"

funct_set_type()
{

  if [[ "$TYPE" == "emulation" ]]; then
    # copy pkg to emulation on libregeek
    sourcedir="/home/desktop/build-deb-temp/git-temp"
    user="thelinu2"
    destdir="/home2/thelinu2/public_html/SteamOS-Extra/emulation"
  fi

}

funct_transfer()
{

  # transfer file
  scp $sourcedir $user@$destdir
}

# main start
fucnt_set_type
funct_transfer

