#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		upload-pkg-to-libregeek.sh
# Script Ver:	  	0.2.1
# Description:		upload completed deb packages to libregeek.org
#
# Usage:          ./upload-pkg-to-libregeek.sh
# -------------------------------------------------------------------------------

TYPE="$1"
script_dir="$PWD"

#Set defaults if user doesn't enter a TYPE
sourcedir="/home/desktop/build-deb-temp/"

funct_set_vars()
{
  
  sourcedir="/home/desktop/build-deb-temp/"
  user="thelinu2"
  host="libregeek.org"
  
}

funct_set_dir()
{
  
  # set path for upload
echo -e "\nPlease select which SteamOS-Extra folder you would like the package uploaded: \n"
echo -e "(1) SteamOS-Extra/emulation"
echo -e "(2) SteamOS-Extra/emulation-src"
echo -e "(3) SteamOS-Extra/browser"
echo -e "(4) SteamOS-Extra/utilities"
echo -e "(5) SteamOS-Extra/misc"
echo -e "(6) SteamOS-Extra/Multimedia"
echo -e "(6) Default Public HTML\n"

# the prompt sometimes likes to jump above sleep
sleep 0.5s

read -ep "Choice: " dir_choice

case "$dir_choice" in
        
      1)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/emulation"
      ;;
      
      2)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/emulation-src"
      ;;
      
      3)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/browsers"
      ;;
      
      4)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/utlities"
      ;;
      
      5)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/misc"
      ;;
      
      6)
      destdir="/home2/thelinu2/public_html/SteamOS-Extra/multimedia"
      ;;
      
      7)
      destdir="/home2/thelinu2/public_html/"
      ;;
      
esac

}

funct_transfer()
{

  # transfer file
  scp $sourcedir/$PKG $user@$host:$destdir
}

main()
{
  


while [[ "$PKG" != "done" ]];
do
	clear
	echo -e "\nPlease the package you wish to upload."
	echo -e "When finished, please enter the word 'done' without quotes\n"
	sleep 1s
	echo -e "\n==> Displaying contents of $sourcedir:\n"
	sleep 2s
	
	ls "$sourcedir"
	cd $sourcedir
	echo ""
	
	# capture command
	read -ep "Package to upload >> " PKG
	
	# ignore executing src_cmd if "done"
	if [[ "$PKG" == "done" ]]; then
		# do nothing
		echo "" > /dev/null
	fi

	# set dir and transfer
	funct_set_dir
	funct_transfer

done

}

##############################################
# main start
##############################################
main

