#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	add-debian-repos.sh
# Script Ver:	0.1.1
# Description:	This script automatically enables debian repositories
# Usage:	./add-debian-repos [install|uninstall]
# ------------------------------------------------------------------------

# Set default user option
install="yes"

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then
	clear
	printf "\nScript must be run as root! Try:\n\n"
	printf "'sudo ./add-debian-repos.sh install'\n\n"
	printf "OR\n"
	printf "\n'sudo ./add-debian-repos.sh uninstall'\n\n"
	exit 1
fi

# valid chipset values: nvidia, intel, fglrx
if [[ "$1" == "install" ]]; then
	install="yes"
elif [[ "$1" == "uninstall" ]]; then
    	install="no"
fi

# Install/Uninstall process

if [[ "$install" == "yes" ]]; then
	clear
	echo "Adding debian repositroies..."
	sleep 1s
	
	# Check for exitance of /etc/apt/preferences
	if [[ -d "/etc/apt/preferences" ]]; then
		# backup preferences file
		mv "/etc/apt/preferences" "/etc/apt/preferences.bak"
	fi

	# Create and add required text to preferences file
	touch "/etc/apt/preferences"

	echo "Package: *" > "/etc/apt/preferences"
	echo "Pin: release l=SteamOS" >> "/etc/apt/preferences"
	echo "Pin-Priority: 900" >> "/etc/apt/preferences"
	echo "" >> "/etc/apt/preferences"
	echo "Package: *" >> "/etc/apt/preferences"
	echo "Pin: release l=Debian" >> "/etc/apt/preferences"
	echo "Pin-Priority:-110" >> "/etc/apt/preferences"

	# Check for Wheezy list in repos.d
	# If it does not exist, create it
	if [[ -f "/etc/apt/sources.list.d/wheezy.list" ]]; then
        	# backup sources list file
        	mv "/etc/apt/sources.list.d/wheezy.list" "/etc/apt/sources.list.d/wheezy.list.bak"
	fi

	# Create and add required text to wheezy.list
	touch "/etc/apt/sources.list.d/wheezy.list"

	echo "## internal SteamOS repo" > "/etc/apt/sources.list.d/wheezy.list"
	echo "deb http://repo.steampowered.com/steamos alchemist main contrib non-free" >> "/etc/apt/sources.list.d/wheezy.list"
	echo "deb-src http://repo.steampowered.com/steamos alchemist main contrib non-free"  >>  "/etc/apt/sources.list.d/wheezy.list"

	# Update system
	sudo apt-get update

	# Remind user how to install
	clear

	echo "###########################################################"
	echo "How to use"
	echo "###########################################################"
	echo ""
	echo "To install software, first check that it does not exist in"
	echo "the Alchemist / Alchemist Beta repositories by trying:"
	echo ""
	echo "'sudo apt-get install <package_name>'"
	echo ""
	echo "If the package does not exist, install it from the Wheezy repos"
	echo "using the following command:"
	echo ""
	echo "'sudo apt-get -t wheezy <package_name>'"
	echo ""
	echo "Warning: If the apt package manager seems to want to remove a"
	echo "lot of packages you have already installed, be very careful about"
	echo "proceeding. Backup your root partition with the SteamOS boot"
	echo "up root capture option first!!! You've been warned!"
	echo ""

elif [[ "$install" == "no" ]]; then
	clear
	echo "Removing debian repositroies..."
	sleep 1s
	sudo rm -f "/etc/apt/preferecnes"
	sudo rm -f "/etc/apt/sources.list.d/wheezy.list"
	echo ""
	apt-get update
fi
