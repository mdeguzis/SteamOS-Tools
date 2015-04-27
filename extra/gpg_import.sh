#!/bin/bash
# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	emu-from-source.sh
# Script Ver:	  	0.1.2
# Description:		script to add and export a gpg key
# -------------------------------------------------------------------------------
key="$1"
keyserver="hkp://subkeys.pgp.net"

#--no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg
gpg --keyserver  $keyserver --recv-keys $key
gpg -a --export $key | sudo apt-key add -
