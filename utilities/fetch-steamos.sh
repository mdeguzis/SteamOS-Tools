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
  
  echo -e "==> Fetching $release\n"
  
  if [[ -f "$download_dir/SteamOS.DVD.iso" 
     && -f "$download_dir/SteamOSInstaller.zip"
     ]]; then
    echo -e "$release release installer files found, overwrite?"
    
    # get user choice
  	read -erp "Choice: " choice
  	
    if [[ "choice" == "y" ]]; then
      wget -r "http://repo.steampowered.com/download/$release/*"
    else
      echo -e "Skipping download\n"
    fi
    
  else
  
    echo -e "$release Release not found in target directory." 
    echo -e "Downloading to: $download_dir"
    sleep 2s
    cd "$download_dir"
    wget --content-disposition --no-parent --recursive --level=1 --no-directories --reject "index.html*" \
    http://repo.steampowered.com/download/alchemist/
  
  fi
  
}

pre_reqs()
{
  #####################
  # directories
  #####################
  
  # check fo existance of dirs
  
  if [[ ! -d "$download_dir" ]]; then
    mkdir -p "$download_dir"
  fi

}

main()
{
  
  # remove any duplicated files. If something went wrong and we ended
  # up with, for instance, SteamOSDVD.iso.1, let's remove that
  #find "$download_dir/alchemist" -name *.so | xargs sudo cp -t "/usr/lib/libretro" 2> /dev/null
  
  # testing
  exit 1
  
  # dowload alchemist
  release="alchemist"
  download_dir="/home/$USER/downloads/alchemist"
  pre_reqs
  download_release
  
  # download brewmaster
  #release="brewmaster"
  #pre_reqs
  #download_dir="/home/$USER/downloads/brewmaster"
  
}

# Start script
main

