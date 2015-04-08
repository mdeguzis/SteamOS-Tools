#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	add-debian-repos.sh
# Script Ver:	0.1.3
# Description:	This script automatically enables debian repositories
#		The script must be run as root to add the source list
#		lines to system directory locations.
# Usage:	sudo ./add-debian-repos [install|uninstall|--help]
# ------------------------------------------------------------------------

funct_set_vars()
{
	# Set default user option
	install="yes"
	reponame="wheezy"
	backports_reponame="wheezy-backports"
	sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	backports_sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	prefer="/etc/apt/preferences.d/${reponame}"
	backports_prefer="/etc/apt/preferences.d/${backports_reponame}"
	steamosprefer="/etc/apt/preferences.d/steamos"
}

show_help()
{
	clear
	echo "###########################################################"
	echo "Usage instructions"
	echo "###########################################################"
	echo -e "\nYou can run this script as such," 
	echo -e "\n\n'sudo add-debian-repos.sh\n"
	
}

funct_show_warning()
{
	# Warn user script must be run as root
	if [ "$(id -u)" -ne 0 ]; then
		clear
		printf "\nScript must be run as root! Try:\n\n"
		printf "'sudo $0 install'\n\n"
		printf "OR\n"
		printf "\n'sudo $0 uninstall'\n\n"
		exit 1
	fi
}

funct_option_check()
{
	# check for and set install status
	if [[ "$1" == "install" ]]; then
		install="yes"
	elif [[ "$1" == "uninstall" ]]; then
	    	install="no"
	fi
}

main()
{
	# Install/Uninstall process
	if [[ "$install" == "yes" ]]; then
		clear
		echo -e "Adding debian repositories...\n"
		sleep 1s
		
		# Check for existance of /etc/apt/preferences
		if [[ -f ${prefer} ]]; then
			# backup preferences file
			echo "Backup up ${prefer} to ${prefer}.bak"
			mv ${prefer} ${prefer}.bak
		fi
		
		if [[ -f ${backports_prefer} ]]; then
			# backup preferences file
			echo "Backup up ${backports_prefer} to ${backports_prefer}.bak"
			mv ${backports_prefer} ${backports_prefer}.bak
		fi
	
		# Create and add required text to preferences file
		cat <<-EOF >> ${prefer}
		Package: *
		Pin: release l=Debian
		Pin-Priority: 110
		EOF
		
		cat <<-EOF >> ${prefer-backports}
		Package: *
		Pin: release a=wheezy-backports
		Pin-Priority: 100
		EOF
	
		cat <<-EOF >> ${steamosprefer}
		Package: *
		Pin: release l=SteamOS
		Pin-Priority: 900
		EOF

		# Check for Wheezy lists in repos.d
		# If it does not exist, create it
		
		if [[ -f ${sourcelist} ]]; then
	        	# backup sources list file
	        	echo "Backup up ${sourcelist} to ${sourcelist}.bak"
	        	mv ${sourcelist} ${sourcelist}.bak
		fi
		
		if [[ -f ${backports_sourcelist} ]]; then
	        	# backup sources list file
	        	echo "Backup up ${backports_sourcelist} to ${backports_sourcelist}.bak"
	        	mv ${backports_sourcelist} ${backports_sourcelist}.bak
		fi
	
	
		# Create and add required text to wheezy.list

		cat <<-EOF >> ${sourcelist}
		# Debian-Wheezy repo
		deb ftp://mirror.nl.leaseweb.net/debian/ wheezy main contrib non-free
		deb-src ftp://mirror.nl.leaseweb.net/debian/ wheezy main contrib non-free
		
		# Debian-Wheezy-Backports
		deb http://http.debian.net/debian wheezy-backports main
		EOF

		# Update system
		echo "Updating index of packages..."
		apt-get update
	
		# Remind user how to install
		clear
		echo -e "\n###########################################################"
		echo "How to use"
		echo "###########################################################"
		echo -e "\nYou can now not only install package from the SteamOS repository," 
		echo -e "but also from the Debian repository with:\n\n"
		echo -e "'sudo apt-get install <package_name>'\n"
		echo -e "or\n"
		echo -e "'sudo apt-get -t [wheezy|wheezy-backports] install <package_name>'\n\n"
		echo "Warning: If the apt package manager seems to want to remove a"
		echo "lot of packages you have already installed, be very careful about"
		echo -e "proceeding.\n"
	
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
}

#Show help if requested
if [[ "$1" == "--help" ]]; then
        show_help
	exit 0
fi

# Start Script
funct_set_vars
funct_show_warning
funct_option_check
main
