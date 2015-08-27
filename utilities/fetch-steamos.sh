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

clear

download_release()
{

  # check fo existance of dirs
  if [[ ! -d "$HOME/downloads/$release" ]]; then
    mkdir -p "$HOME/downloads/$release"
  fi
  
  # check for file existance
  if [[ -f "$HOME/downloads/$release/$file" ]]; then
    
    echo -e "\nFile exists, overwrite? (y/n)"
    read -ep "Choice: " dl_choice
  
  fi
  
  case "$dl_choice" in
    
    y)
    # download requested file
    cd "$HOME/downloads/$release"
    wget --no-parent --recursive --no-directories --reject "index.html*" \
    --no-clobber http://repo.steampowered.com/download/$release/$file
    
    # download MD5 or SHA file
    if [[ "$file" == "SteamOSInstaller.zip" ]]; then
    
      rm -f "$HOME/downloads/$release/MD5SUM"
      wget "$base_url/$release/MD5SUMS"
      # replace downlaod location in file
      sed -i 'g|/var/www/download|$HOME/downloads/$release|g' "$HOME/downloads/$release/MD5SUM"
      
    fi    
      
    ;;
    
    n)
    echo -e "Aborting..."
    clear
    exit 1
    ;;
  
  esac
  
}

main()
{
    # set base URL
    base_url="repo.steampowered.com/download"
    base_dir="$HOME/downloads"
  
  	# prompt user if they would like to load a controller config
  	echo -e "\nPlease choose a release to download. Releases checked for integrity: \n"
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
    download_release
    check_integrity
    ;;
    
    2)
    
    ;;
    
    3)
    
    ;;
    
    4)
    
    
    *)
    echo "Invalid Input, exiting"
    exit 1
    ;;
    
	esac
 
} 

check_download_integrity()
{
  
  echo -e "\n==> Checking integrity of installer\n"
  MD5SUM -c "$HOME/downloads/$release/$file" "$HOME/downloads/$release/MD5SUM"
  
}

# Start script
main

