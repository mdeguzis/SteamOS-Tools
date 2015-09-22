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

utlitity_dir=$(pwd)

clear
cat<<- EOF
----------------------------------------------------------------
SteamOS-Tools test suite
----------------------------------------------------------------
This script only* tests functionality, syntax errors. If a 
command fails you will see it below as [FAIL] beneath the test.

Some tests take some time to complete, so please let the test
finish.

[c] to continue or [e] to exit
EOF

read -erp "Choice: " choice

if [[ "$choice" == "c" ]]; then

  ####################################################
  # desktop-software.sh - install Debian software
  ####################################################
  
  pkg="gedit"
  test="desktop-software.sh install gedit"
  
  cd ..
  echo -e "\n[Running Test] $test" 
  
  if echo c | ./desktop-software.sh install ${pkg} | while read -r line; do echo -n $'\r'"$line"; done; then
    echo "[PASS]"
  else
    echo "[FAIL]"
  fi
  
  # return to script dir
  cd "$utlitity_dir"
  
  ####################################################
  # desktop-software.sh - Remove Debian software
  ####################################################
  
  pkg="gedit"
  test="desktop-software.sh remove gedit"
  
  cd ..
  echo -e "\n[Running Test] $test " 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "[PASS]"
  else
    echo "[FAIL]"
  fi
  
  # return to script dir
  cd "$utlitity_dir"
  
  ####################################################
  # desktop-software.sh - install Libregeek software
  ####################################################
  
  pkg="lutris"
  test="desktop-software.sh Install lutris"
  
  cd ..
  echo -e "\n[Running Test] $test " 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "[PASS]"
  else
    echo "[FAIL]"
  fi
  
  # return to script dir
  cd "$utlitity_dir"
  
  ####################################################
  # desktop-software.sh - remove Libregeek software
  ####################################################
  
  pkg="lutris"
  test="desktop-software.sh remove lutris"
  
  cd ..
  echo -e "\n[Running Test] $test " 
  
  if echo c | ./desktop-software.sh install ${pkg} &> /dev/null; then
    echo "[PASS]"
  else
    echo "[FAIL]"
  fi
  
  # return to script dir
  cd "$utlitity_dir"
  
elif [[ "$choice" == "e" ]]; then

  exit 1

fi
   
