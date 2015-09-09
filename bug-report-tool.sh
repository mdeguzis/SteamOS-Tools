#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  bug-report-tool.sh
# Script Ver:	  0.1.1
# Description:	Captures important system information in a semi-readible format
#               to attach to a SteamOS bug report at github.com/ValveSoftware/SteamOS/issues
#
# Usage:	      bug-report-tool.sh
#
# -------------------------------------------------------------------------------

# prereqs

sudo apt-get install git

# function to paste to gist
# sourced from Stack exchange

function msg() {
  echo -n '{"description":"","public":"false","files":{"file1.txt":{"content":"'
  sed 's:":\\":g' "$1"
  echo '"}}'
}

[ "$#" -ne 1 ] && echo "Syntax: gist.sh filename" && exit 1
[ ! -r "$1" ] && echo "Error: unable to read $1" && exit 2

# lspci
msg "lspci -v" | curl -v -d '@-' https://api.github.com/gists
