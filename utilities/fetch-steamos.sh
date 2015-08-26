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

#####################
# directories
#####################

# check fo existance of dirs

if [[ ! -d $"a_download_dir" ]]; then
  mkdir -p "$a_download_dir"
fi

if [[ ! -d $"b_download_dir" ]]; then
  mkdir -p "$b_download_dir"
fi

download_release()
{
  
  echo -e "==> Fetching $release"
  
  if [[ -f "$download_dir/SteamOS.DVD.iso" 
     && -f "$download_dir/SteamOSInstaller.zip" 
     &&
     ]]; then
    echo -e "$release release installers found, overwrite?"
    
    # get user choice
  	read -erp "Choice: " choice
  	
    if [[ "choice" == "y" ]]; then
      wget -r "http://repo.steampowered.com/download/$release/*"
    else
      echo -e "Skipping download\n"
    fi
    
  else
    echo -e "$release Release not found in target directory. Downloading now"
    sleep 2s
    cd "$download_dir"
    wget --no-parent --recursive --level=1 --no-directories --reject "index.html*" \
    http://repo.steampowered.com/download/alchemist/
  
  fi
  
}

main()
{
  
  # dowload alchemist
  release="alchemist"
  download_dir="/home/$USER/downlaods/alchemist"
  download_release
  
  # download brewmaster
  #release="brewmaster"
  #download_dir="/home/$USER/downlaods/brewmaster"
  
}

# Start script
main

