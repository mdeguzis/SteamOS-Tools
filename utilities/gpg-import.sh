#!/bin/bash
# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	emu-from-source.sh
# Script Ver:	  	0.1.3
# Description:		script to add and export a gpg key
# -------------------------------------------------------------------------------

# define key for argument
key="$1"

# Choose keyserver to use
# Keep a good list here so that we have backups if certain ones are not functioning

#keyserver="hkp://subkeys.pgp.net"
keyserver="pool.sks-keyservers.net"
#keyserver="na.pool.sks-keyservers.net"
#keyserver="pgp.mit.edu"
#keyserver="http://keyserver.ubuntu.com"
#keyserver="keys.gnupg.net"

# import gpg key
gpg --keyserver $keyserver --recv-keys $key
gpg -a --export $key | sudo apt-key add -
sudo apt-key update
