#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	  	Michael DeGuzis
# Git:			      https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	fetch-steamos.sh
# Script Ver:		  0.1.1
# Description:		Fetch latest Alchemist and Brewmaster SteamOS release files
#                 to specified directory and run SHA512 checks against them.
#
# Usage:      		./fetch-steamos.sh
# -------------------------------------------------------------------------------

check_download_integrity()
{
  
  echo -e "\n==> Checking integrity of installer\n"
  
  echo -e "\nMD5 Check:"
  MD5SUM -c "$HOME/downloads/$release/$file" "$HOME/downloads/$release/MD5SUM"
  
  echo -e "\nSHA512 Check:"
  SHA512SUM -c "$HOME/downloads/$release/$file" "$HOME/downloads/$release/SHA512SUMS"
  
}

check_file_existance()
{
	
	# check fo existance of dirs
	if [[ ! -d "$HOME/downloads/$release" ]]; then
		mkdir -p "$HOME/downloads/$release"
	fi
  
	# check for file existance
	if [[ -f "$HOME/downloads/$release/$file" ]]; then
	
		echo -e "\nFile exists, overwrite? (y/n)"
		read -ep "Choice: " dl_choice
		
		if [[ "$dl_choice" == "y" ]]; then
			download_release
		else
			echo -e "\nAborting..."
			clear
			exit 1
		fi

  	else
	
}

download_release()
{
	
	# download requested file
	cd "$HOME/downloads/$release"
	wget --no-parent --recursive --no-directories --reject "index.html*" \
	--no-clobber http://repo.steampowered.com/download/$release/$file
	
	# download MD5 and SHA files
	rm -f "$HOME/downloads/$release/MD5SUM"
	rm -f "$HOME/downloads/$release/SHAD512SUMS"
	
	wget "$base_url/$release/MD5SUMS"
	wget "$base_url/$release/SHA512SUMS"

	# replace download location in integrity check files
	sed -i 'g|/var/www/download|$HOME/downloads/$release|g' "$HOME/downloads/$release/MD5SUM"
	sed -i 'g|/var/www/download|$HOME/downloads/$release|g' "$HOME/downloads/$release/SHA512SUMS"
}

main()
{
    # set base URL
    base_url="repo.steampowered.com/download"
    base_dir="$HOME/downloads"
  
  	# prompt user if they would like to load a controller config
  	echo -e "\nPlease choose a release to download. Releases checked for integrity \n"
  	echo "(1) Alchemist (standard zip, UEFI only)"
  	echo "(2) Alchemist (legacy ISO, BIOS systems)"
  	echo "(3) Brewmaster (standard zip, UEFI only)"
  	echo "(4) Brewmaster (legacy ISO, BIOS systems)"
  	echo ""
  	echo ""
  	
  	# the prompt sometimes likes to jump above sleep
	sleep 0.5s
	
	read -ep "Choice: " rel_choice
	
  case "$rel_choice" in
    1)
    release="alchemist"
    file="$base_url/SteamOSInstaller.zip"
    check_file_existance
    download_release
    check_integrity
    ;;
    
    2)
    
    ;;
    
    3)
    
    ;;
    
    4)
    ;;
    
    *)
    echo "Invalid Input, exiting"
    exit 1
    ;;
    
	esac
 
} 

# Start script
main

