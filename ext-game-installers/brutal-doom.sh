#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      brutal-doom.sh
# Script Ver:	      0.0.1
# Description:	    Installs the latest Brutal Doom under Linux / SteamOS
#                   Based off of https://github.com/coelckers/gzdoom
#                   Compile using CMake.
#
# Usage:	          ./dbrutal-doom.sh
# Help:         		./desktop-software.sh --help
#
# Warning:	        You MUST have the Debian repos added properly for
#	                	Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# set scriptdir
scriptdir="/home/desktop/SteamOS-Tools"

############################################
# vars
############################################

brutal_dir="/home/steam/brutal-doom"

# GPG key for building using "build-deb-from-ppa"
# deb-src http://archive.getdeb.net/ubuntu vivid-getdeb apps
# A8A515F046D7E7CF

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


