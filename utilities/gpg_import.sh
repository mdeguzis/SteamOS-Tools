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

#keyserver="hkp://subkeys.pgp.net"
keyserver="pgp.mit.edu"

# import gpg key
gpg --keyserver $keyserver --recv-keys $key
gpg -a --export $key | sudo apt-key add - >2>&1 >/dev/null
sudo apt-key update
