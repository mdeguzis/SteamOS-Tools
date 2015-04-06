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

reponame="wheezy"
sourcelist="/etc/apt/sources.list.d/${reponame}.list"
prefer="/etc/apt/preferences.d/${reponame}"
steamosprefer="/etc/apt/preferences.d/steamos"


# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then
	clear
	printf "\nScript must be run as root! Try:\n\n"
	printf "'sudo $0 install'\n\n"
	printf "OR\n"
	printf "\n'sudo $0 uninstall'\n\n"
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
	echo -e "Adding debian repositories...\n"
	sleep 1s
	
	# Check for exitance of /etc/apt/preferences
	if [[ -f ${prefer} ]]; then
		# backup preferences file
		echo "Backup up ${prefer} to ${prefer}.bak"
		mv ${prefer} ${prefer}.bak
	fi

	# Create and add required text to preferences file
	cat << EOF >> ${prefer}
Package: *
Pin: release l=Debian
Pin-Priority: 110
EOF

	cat << EOF >> ${steamosprefer}
Package: *
Pin: release l=SteamOS
Pin-Priority: 900
EOF

	# Check for Wheezy list in repos.d
	# If it does not exist, create it
	if [[ -f ${sourcelist} ]]; then
        	# backup sources list file
        	echo "Backup up ${sourcelist} to ${sourcelist}.bak"
        	mv ${sourcelist} ${sourcelist}.bak
	fi

	# Create and add required text to wheezy.list
	cat << EOF >> ${sourcelist}
## Debian repo
deb ftp://mirror.nl.leaseweb.net/debian/ wheezy main contrib non-free
deb-src ftp://mirror.nl.leaseweb.net/debian/ wheezy main contrib non-free
EOF
	# Update system
	echo "Updating index of packages..."
	apt-get update

	# Remind user how to install
	clear

	echo "###########################################################"
	echo "How to use"
	echo "###########################################################"
	echo ""
	echo "You can now not only install package from the SteamOS repository, but also from the Debian repository with:"
	echo ""
	echo "'sudo apt-get install <package_name>'"
	echo ""
	echo "Warning: If the apt package manager seems to want to remove a"
	echo "lot of packages you have already installed, be very careful about"
	echo "proceeding."
	echo ""

elif [[ "$install" == "no" ]]; then
	clear
	echo "Removing debian repositories..."
	rm ${sourcelist}
	rm ${prefer}
	rm ${steamosprefer}
	echo "Updating index of packages..."
	apt-get update
	echo "Done!"
fi
