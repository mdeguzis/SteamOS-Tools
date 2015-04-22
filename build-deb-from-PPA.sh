#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-deb-from-PPA.sh
# Script Ver:	0.1.1
# Description:	Attempts to build a deb package from a PPA
#
# Usage:	sudo ./build-deb-from-PPA.sh [target_package]
#
# -------------------------------------------------------------------------------

install_prereqs()
{
	# install needed packages
	apt-get install devscripts build-essential

}

check_for_sudo()
{
	# Warn user script must be run as root
	if [ "$(id -u)" -ne 0 ]; then
		clear
		printf "\nScript must be run as root! Try:\n\n"
		printf "'sudo $0'\n\n"
		exit 1
	fi
}

main()
{
	clear
	# remove previous dirs if they exist
	if [[ -d "~/build-deb-temp" ]]; then
		rm -rf "~/build-deb-temp"
	fi
	
	# create build dir and enter it
	mkdir -p "~/build-deb-temp"
	cd "/home/desktop/build-deb-temp"
	
	# Ask user for repos / vars
	echo -e "Please enter or paste the repo src URL now:"
	read repo_src
	
	echo -e "\nPlease enter or paste the GPG key for this repo now:"
	read gpg_pub_key
	
	echo -e "\nPlease enter or paste the desired package name now:"
	read target
	
	# prechecks
	echo -e "\n==>Attempting to add source list\n"
	sleep 2s
	
	# check for existance of target, backup if it exists
	if [[ -f /etc/apt/sources.list.d/${target}.list ]]; then
		mv "/etc/apt/sources.list.d/${target}.list" "/etc/apt/sources.list.d/${target}.list.bak"
	fi
	
	# add source to sources.list.d/
	echo ${repo_src} > "/etc/apt/sources.list.d/${target}.list"
	
	echo -e "\n==>Adding GPG key:\n"
	sleep 2s
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ${gpg_pub_key}
	
	echo -e "\n==>Updating system package listings...\n"
	sleep 2s
	apt-get update
	
	#Attempt to build target
	echo -e "\n==>Attemption to build ${target}:\n"
	sleep 2s
	apt-get source --build ${target}
	
	# back out of build temp
	cd
	
	# inform user of packages
	echo -e "\n###################################################################"
	echo -e "If package was built without errors you will see if below."
	echo -e "If you do not, please check build dependcy errors listed above."
	echo -e "You could also try manually building outside of this script with"
	echo -e "'sudo apt-get --nodeps source --build ${target}"
	echo -e "###################################################################\n"
	
	ls "/home/desktop/build-deb-temp" | grep ${target}*.deb
}

# start main
check_for_sudo
main
