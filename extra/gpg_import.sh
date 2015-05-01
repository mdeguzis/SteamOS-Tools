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

if [[ "$scriptdir" != ]]; then
  # set to scriptdir
  gpg_cmd="$scriptdir/extra/gpg_import.sh $key"
else
  # run from current dir
  gpg_cmd="gpg_import.sh"
fi

if [[ "$gpg_key_check" != "" ]]; then
  echo -e "\nGPG key "$key" [OK]\n"
  sleep 1s
else
  echo -e "\nGPG key "$key" [FAIL]. Adding now...\n"
  "$gpg_cmd"
fi

#--no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg
gpg --keyserver  $keyserver --recv-keys $key
gpg -a --export $key | sudo apt-key add -
