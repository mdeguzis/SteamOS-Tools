#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      brutal-doom.sh
# Script Ver:	      0.0.1
# Description:	    Installs the latest Brutal Doom under Linux / SteamOS
#
#
# Usage:	          ./dbrutal-doom.sh
# Help:         		./desktop-software.sh --help
#
# Warning:	        You MUST have the Debian repos added properly for
#	                	Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

############################################
# vars
############################################
brutal_dir="/home/steam/brutal-doom"

############################################
# Prerequisite packages
############################################

############################################
# Create folders for Project
############################################

echo -n "\n==> Checkin for Brutal Doom directory"

if [[ -d "$brutal_dir" ]]
  echo -n "\nBrutal Doom directory found"
else
  sudo mkdir $brutal_dir
fi

############################################
# install GZDoom
############################################

# Ubuntu package needs rebuilt !!!

############################################
# Configure
############################################


