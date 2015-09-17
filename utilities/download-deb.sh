#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  download-deb.sh
# Script Ver:	  0.1.1
# Description:	Download deb file only to $1 pool, and $2 pool for $3 pkg
#               Meant for internal use only.
#
# Usage:	      ./download-deb.sh [dir] [pkg]

# -------------------------------------------------------------------------------

# vars
dir="$1"
pool="$2"

# cd to pool for easier TAB autocomplete
# Remaining structure: pool/main/<LETTER>
cd $HOME/packaging/SteamOS-Tools

# download pkg
sudo apt-get -o dir::cache::archives="$dir" -d install $pkg
