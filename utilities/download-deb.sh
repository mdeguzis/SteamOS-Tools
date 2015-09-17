#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  download-deb.sh
# Script Ver:	  0.1.1
# Description:	Download deb file only to $1 pool, and $2 pool for $3 pkg
#               Meant for internal use only. Relies on source being available
#               for download of package and LAN host target.
#
# Usage:	      ./download-deb.sh [pkg]

# -------------------------------------------------------------------------------

# vars
pkg="$2"

# set base dir
basedir="$HOME/packaging/SteamOS-Tools"

# get source dir from prompt
read -ep "Pool dir to download to? [letter only]: " letter
sleep 0.3s

download_dest="$HOME/packaging/SteamOS-Tools/pool/main/$letter"

# created pool dir if it does not exist
if [[ ! -d "$download_dest" ]]; then

  # create dir
  mkdir -p $download_dest
  
fi

# enter base dir
cd $basedir

# download pkg
sudo apt-get -o dir::cache::archives="$download_dest" -d install $pkg

# upload to libregeek target pool
scp $sourcedir/$PKG thelinu2@libregeek.org:/home2/thelinu2/public_html/packages/SteamOS-Tools/pool/main/$

# ask to sync pool
# get source dir from prompt
read -ep "Sync pool to remote server? [y/n]" sync
sleep 0.3s

if [[ "$sync" == "y" ]]; then

  # sync
  $HOME/packaging/SteamOS-Tools/sync-pool.sh
  
elif [[ "$sync" == "n" ]]; then

  # do not sync
  echo -e "\nSync skipped"
  
else
  
  # error
  echo -e "\nERROR"
fi
