#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	add-debian-repos.sh
# Script Ver:	0.2.0
# Description:	This script automatically enables debian repositories
#
#		See: https://wiki.debian.org/AptPreferences#Pinning
#
# Usage:	./add-debian-repos [install|uninstall|--help]
# ------------------------------------------------------------------------

# remove old custom files
rm -f "log.txt"

# set default action if no args are specified
install="yes"

# check for and set install status
if [[ "$1" == "install" ]]; then
	install="yes"
elif [[ "$1" == "uninstall" ]]; then
    	install="no"
fi

funct_set_vars()
{
	# Set default user options
	reponame="jessie"
	backports_reponame="jessie-backports"
	
	# tmp vars
	sourcelist_tmp="${reponame}.list"
	backports_sourcelist_tmp="${backports_reponame}.list"
	prefer_tmp="${reponame}"
	backports_prefer_tmp="${backports_reponame}"
	steamos_prefer_tmp="steamos"
	
	# target vars
	sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	backports_sourcelist="/etc/apt/sources.list.d/${backports_reponame}.list"
	prefer="/etc/apt/preferences.d/${reponame}"
	backports_prefer="/etc/apt/preferences.d/${backports_reponame}"
	steamos_prefer="/etc/apt/preferences.d/steamos"
	
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
	# not called for now
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

main()
{

	#####################################################
	# old release targets
	#####################################################
	
	# old targets
	# remove old targets that should not be used with jessie / brewmaster
	
	if [[ -f "/etc/apt/preferences.d/wheezy" ]]; then
		# delete preferences file
		sudo rm -f /etc/apt/preferences.d/wheezy*
		sleep 1s
	fi
	
	if [[ -f "/etc/apt/sources.list.d/wheezy" ]]; then
		# delete sources file
		sudo rm -f /etc/apt/sources.list.d/wheezy*
		sleep 1s
	fi
	
	#####################################################
	# Install/Uninstall process
	#####################################################
	
	if [[ "$install" == "yes" ]]; then
		clear
		echo -e "==> Adding Debian ${reponame} and ${backports_reponame} repositories\n"
		sleep 1s
		
		# Check for existance of /etc/apt/preferences file (deprecated, see below)
		if [[ -f "/etc/apt/preferences" ]]; then
			# backup preferences file
			echo -e "==> Backing up /etc/apt/preferences to /etc/apt/preferences.bak\n"
			sudo mv "/etc/apt/preferences" "/etc/apt/preferences.bak"
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{steamos_prefe} file
		if [[ -f ${steamos_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${steamos_prefer} to ${steamos_prefer}.bak\n"
			sudo mv ${steamos_prefer} ${steamos_prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{prefer} file
		if [[ -f ${prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${prefer} to ${prefer}.bak\n"
			sudo mv ${prefer} ${prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{backports_prefer} file
		if [[ -f ${backports_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${backports_prefer} to ${backports_prefer}.bak\n"
			sudo mv ${backports_prefer} ${backports_prefer}.bak
			sleep 1s
		fi
	
		# Create and add required text to preferences file
		# Verified policy with apt-cache policy
		cat <<-EOF > ${prefer_tmp}
		Package: *
		Pin: origin ""
		Pin-Priority:110
		
		Package: *
		Pin: release o=Debian 
		Pin-Priority:110
		EOF
		
		cat <<-EOF > ${backports_prefer_tmp}
		Package: *
		Pin: origin ""
		Pin-Priority:100
		
		Package: *
		Pin: release o=Debian 
		Pin-Priority:110
		EOF
	
		cat <<-EOF > ${steamos_prefer_tmp}
		Package: *
		Pin: release l=Steam
		Pin-Priority: 900
		
		Package: *
		Pin: release l=SteamOS
		Pin-Priority: 900
		EOF
		
		# move tmp var files into target locations
		sudo mv  ${prefer_tmp}  ${prefer}
		sudo mv  ${backports_prefer_tmp}  ${backports_prefer}
		sudo mv  ${steamos_prefer_tmp}  ${steamos_prefer}
		
		#####################################################
		# Check for lists in repos.d
		#####################################################
		
		# If it does not exist, create it
		
		if [[ -f ${sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${sourcelist} to ${sourcelist}.bak\n"
	        	sudo mv ${sourcelist} ${sourcelist}.bak
	        	sleep 1s
		fi
		
		if [[ -f ${backports_sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${backports_sourcelist} to ${backports_sourcelist}.bak\n"
	        	sudo mv ${backports_sourcelist} ${backports_sourcelist}.bak
	        	sleep 1s
		fi
	
		#####################################################
		# Create and add required text to jessie.list
		#####################################################

		# Debian jessie
		cat <<-EOF > ${sourcelist_tmp}
		# Debian-jessie repo
		deb http://httpredir.debian.org/debian jessie main contrib non-free
		deb-src http://httpredir.debian.org/debian jessie main contrib non-free
		# Debian-jessie updates repo
		deb http://httpredir.debian.org/debian jessie-updates main
		deb-src http://httpredir.debian.org/debian jessie-updates main

		EOF
		
		# Debian jessie-backports
		cat <<-EOF > ${backports_sourcelist_tmp}
		deb http://httpredir.debian.org/debian jessie-backports main contrib non-free
		deb-src http://httpredir.debian.org/debian jessie-backports main contrib non-free
		EOF

		# move tmp var files into target locations
		sudo mv  ${sourcelist_tmp} ${sourcelist}
		sudo mv  ${backports_sourcelist_tmp} ${backports_sourcelist}

		# Update system
		echo -e "\n==> Updating index of packages...\n"
		sleep 2s
		sudo apt-get update
	
		#####################################################
		# Remind user how to install
		#####################################################
		clear
		echo -e "\n###########################################################"
		echo "How to use"
		echo -e "###########################################################"
		echo -e "\nYou can now not only install package from the SteamOS repository," 
		echo -e "but also from the Debian repository with either:\n\n"
		echo -e "'sudo apt-get install <package_name>'"
		echo -e "'sudo apt-get -t [jessie|jessie-backports] install <package_name>'\n"
		echo -e "Warning: If the apt package manager seems to want to remove a lot"
		echo -e "of packages you have already installed, be very careful about proceeding.\n"
	
	elif [[ "$install" == "no" ]]; then
		clear
		echo -e "\n==> Removing debian repositories...\n"
		sleep 2s
		
		# original files
		sudo rm -f ${sourcelist}
		sudo rm -f ${backports_sourcelist}
		sudo rm -f ${prefer}
		sudo rm -f ${steamosprefer}
		
		# backups
		sudo rm -f ${sourcelist}.bak
		sudo rm -f ${backports_sourcelist}.bak
		sudo rm -f ${prefer}.bak
		sudo rm -f ${steamosprefer}.bak
		
		sleep 2s
		sudo apt-get update
		echo "Done!"
	fi
}

#Show help if requested
if [[ "$1" == "--help" ]]; then
        show_help
	exit 0
fi
#####################################################
# handle prerequisite software
#####################################################

funct_set_vars

#####################################################
# MAIN
#####################################################

main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > log.txt

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' log.txt

# remove file not needed anymore
rm -f "log_temp.txt"
