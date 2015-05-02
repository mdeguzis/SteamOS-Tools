#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:		      https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	ssh-rom-transfer.sh
# Script Ver: 	0.1.1
# Description:	This script dumps ROMs over SSH
#
# Usage:	      ./ssh-rom-transfer.sh
# ------------------------------------------------------------------------

echo -e "\nEnter Remote User:"
read user

echo -e "\nEnter remote hostname:"
read host

echo -e "\nEnter remote DIR (use quotes on any single DIR name with spaces):"
read remote_dir

# Show remote list first
echo -e "\nShowing remote listing first...press q to quit listing\n"
sleep 2s

ssh ${user}@${host} ls -l ${remote_dir} | less

echo -e "\nEnter target ROM DIR to copy (use quotes on any single DIR name with spaces):"
read target_dir

# copy ROMs
#sudo scp -r ${user}@${host}:'${remote_dir}/${targer_dir}' "/home/steam/ROMs"

#TESTING
echo "${user}@${host}:'${remote_dir}/${targer_dir}' /home/steam/ROMs"
