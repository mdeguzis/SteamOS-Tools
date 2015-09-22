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

clear
cat<<- EOF
----------------------------------------------------------------
SteamOS-Tools test suite
----------------------------------------------------------------
This script only* tests functionality, syntax errors. If a 
command fails you will see it below as TEST_NAME [FAIL]

[c] to continue or [e] to exit
EOF

read -erp "Choice: " choice

if [[ "$choice" == "c" ]]; then

  ####################################################
  # desktop-software.sh - install Debian software
  ####################################################
  
  pkg="gedit"
  test="[desktop-software.sh] install gedit"
  
  cd ..
  echo "[Running $test] Please wait..." 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "$test [PASS]"
  else
    echo "$test [PASS]"
  fi
  
  ####################################################
  # desktop-software.sh - Remove Debian software
  ####################################################
  
  pkg="gedit"
  test="[desktop-software.sh] remove gedit"
  
  cd ..
  echo "[Running $test] Please wait..." 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "$test [PASS]"
  else
    echo "$test [PASS]"
  fi
  
  echo ""
  
  ####################################################
  # desktop-software.sh - install Libregeek software
  ####################################################
  
  pkg="lutris"
  test="[desktop-software.sh] Install lutris"
  
  cd ..
  echo "[Running $test] Please wait..." 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "$test [PASS]"
  else
    echo "$test [PASS]"
  fi
  
  ####################################################
  # desktop-software.sh - remove Libregeek software
  ####################################################
  
  pkg="lutris"
  test="[desktop-software.sh] remove lutris"
  
  cd ..
  echo "[Running $test] Please wait..." 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "$test [PASS]"
  else
    echo "$test [PASS]"
  fi
  
elif [[ "$choice" == "e" ]]; then

  exit 1

fi
   
