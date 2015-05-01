#!/bin/bash
# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	emu-from-source.sh
# Script Ver:	  	0.2.5
# Description:		script to add and export a gpg key
# -------------------------------------------------------------------------------

# set vars
key="$1"
keyserver="hkp://subkeys.pgp.net"
key_short=$(echo $key | cut -c 8-16)

# name of key in check below is passed from previous script
# echo $gpg_key_name

# check key first to avoid importing twice
gpg_key_check=$(gpg --list-keys "$key_short")

# allow script to run in current DIR if not called previously
if [[ "$scriptdir" != "" ]]; then
  # set to scriptdir
  gpg_cmd="$scriptdir/extra/gpg_import.sh"
elif [[ "$pwd" != "$0" ]]; then
  # if called from a dir tree, such as 'extra/gpg_import.sh', act accordingly.
  gpg_cmd="$0"
else
  # run from current dir
  scriptdir=$(pwd)
  gpg_cmd="$scriptdir/gpg_import.sh"
fi

echo "gpg cmd is $gpg_cmd"
exit

if [[ "$gpg_key_check" != "" ]]; then
  echo -e "\nGPG key "$key" [OK]\n"
  sleep 1s
else
  echo -e "\nGPG key "$key" [FAIL]. Adding now...\n"
  "$gpg_cmd" $key
fi

#Import 
gpg --keyserver  $keyserver --recv-keys $key
gpg -a --export $key | sudo apt-key add -
