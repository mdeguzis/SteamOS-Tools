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

# prereqs
	
	# Adding repositories
	PKG="openssh-server"
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
	
	if [ "" == "$PKG_OK" ]; then
		echo -e "\n$PKG not found. Setting up $PKG.\n"
		sleep 1s
		sudo apt-get install $PKG
	else
		echo "Checking for $PKG [Ok]"
		sleep 0.2s
	fi


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
echo -e "\nExecuting CMD: sudo scp -r $user@host:'$remote_dir/$target_dir' /home/steam/ROMs/temp"
sleep 1s
sudo scp -r $user@$host:'$remote_dir/$target_dir' /home/steam/ROMs/temp
