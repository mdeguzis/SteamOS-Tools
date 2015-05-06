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
script_dir="$PWD"

#Set defaults if user doesn't enter a TYPE
sourcedir="/home/desktop/build-deb-temp/"

funct_set_type()
{

  if [[ "$TYPE" == "emulation" ]]; then
    # copy pkg to emulation on libregeek
    sourcedir="/home/desktop/build-deb-temp/"
    user="thelinu2"
    host="libregeek.org"
    destdir="/home2/thelinu2/public_html/SteamOS-Extra/emulation"
  fi

}

funct_transfer()
{

  # transfer file
  scp $sourcedir/$PKG $user@$host:$destdir
}

##############################################
# main start
##############################################

clear
echo -e "\n==> Displaying contents of $sourcedir:\n"
sleep 2s

ls "$sourcedir"
cd $sourcedir
echo ""

# get pkg from user
read -ep "Package to upload >> " PKG

# evaluate and process
funct_set_type
funct_transfer

