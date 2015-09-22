#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:	      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	test-suite.sh
# Script Ver:	  0.3.1
# Description:	Runs some tests to make sure package installs and functions on a
#               basic level work
#
# Usage:	      test-suite.sh [type]
# -------------------------------------------------------------------------------

##########################################
# desktop-software.sh
##########################################

pkg="gedit"

cd..
if echo c | ./desktop-software.sh install ${pkg}; then
  echo "desktop-software.sh install ${pkg} [PASS]"
else
  echo "desktop-software.sh install ${pkg} [FAIL]"
fi
 
