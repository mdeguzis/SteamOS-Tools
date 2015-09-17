#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	add-debian-repos.sh
# Script Ver:	0.2.1
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
	multimedia_reponame="deb-multimedia"
	steamos_tools_reponame="steamos-tools"
	
	# tmp vars
	sourcelist_tmp="${reponame}.list"
	backports_sourcelist_tmp="${backports_reponame}.list"
	multimedia_sourcelist_tmp="${multimedia_reponame}.list"
	steamos_tools_sourcelist_tmp="${steamos_tools_reponame}.list"
	
	prefer_tmp="${reponame}"
	backports_prefer_tmp="${backports_reponame}"
	multimedia_prefer_tmp="${multimedia_reponame}"
	steamos_prefer_tmp="steamos"
	steamos_tools_prefer_tmp="${steamos_tools_reponame}"
	
	# target vars
	sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	backports_sourcelist="/etc/apt/sources.list.d/${backports_reponame}.list"
	multimedia_sourcelist="/etc/apt/sources.list.d/${multimedia_reponame}.list"
	steamos_tools_sourcelist="/etc/apt/sources.list.d/${steamos_tools_reponame}.list"
	
	prefer="/etc/apt/preferences.d/${reponame}"
	backports_prefer="/etc/apt/preferences.d/${backports_reponame}"
	multimedia_prefer="/etc/apt/preferences.d/${multimedia_reponame}"
	steamos_prefer="/etc/apt/preferences.d/steamos"
	steamos_tools_prefer="/etc/apt/preferences.d/${steamos_tools_reponame}"
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
	# Install/Uninstall process
	#####################################################
	
	if [[ "$install" == "yes" ]]; then
		clear
		
		cat <<-EOF
		==> Adding Debian ${reponame}, ${backports_reponame}, ${steamos_tools_reponame} 
		and ${multimedia_reponame} repositories
		    
		EOF
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
		
		# Check for existance of /etc/apt/preferences.d/{multimedia_prefer} file
		if [[ -f ${multimedia_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${multimedia_prefer} to ${multimedia_prefer}.bak\n"
			sudo mv ${multimedia_prefer} ${multimedia_prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{steamos_tools_prefer} file
		if [[ -f ${steamos_tools_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${steamos_tools_prefer} to ${steamos_tools_prefer}.bak\n"
			sudo mv ${steamos_tools_prefer} ${steamos_tools_prefer}.bak
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
		Pin-Priority:120
		
		Package: *
		Pin: release o=Debian 
		Pin-Priority:110
		EOF
		
		cat <<-EOF > ${multimedia_prefer_tmp}
		Package: *
		Pin: origin ""
		Pin-Priority:100
		EOF
	
		cat <<-EOF > ${steamos_prefer_tmp}
		Package: *
		Pin: release l=Steam
		Pin-Priority: 900
		
		Package: *
		Pin: release l=SteamOS
		Pin-Priority: 900
		EOF
		
		cat <<-EOF > ${steamos_tools_prefer_tmp}
		Package: *
		Pin: origin "steamos-tools"
		Pin-Priority:150
		EOF
		
		# move tmp var files into target locations
		sudo mv  ${prefer_tmp}  ${prefer}
		sudo mv  ${backports_prefer_tmp}  ${backports_prefer}
		sudo mv  ${multimedia_prefer_tmp}  ${multimedia_prefer}
		sudo mv  ${steamos_prefer_tmp}  ${steamos_prefer}
		sudo mv  ${steamos_tools_prefer_tmp}  ${steamos_tools_prefer}
		
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
	
		if [[ -f ${multimedia_sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${multimedia_sourcelist} to ${multimedia_sourcelist}.bak\n"
	        	sudo mv ${multimedia_sourcelist} ${multimedia_sourcelist}.bak
	        	sleep 1s
		fi
		
		if [[ -f ${steamos_tools_sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${steamos_tools_sourcelist} to ${steamos_tools_sourcelist}.bak\n"
	        	sudo mv ${steamos_tools_sourcelist} ${steamos_tools_sourcelist}.bak
	        	sleep 1s
		fi

		#####################################################
		# Create and add required text to jessie.list
		#####################################################

		# Debian jessie
		cat <<-EOF > ${sourcelist_tmp}
		# Debian-jessie repo
		deb ftp://mirror.nl.leaseweb.net/debian/ jessie main contrib non-free
		deb-src ftp://mirror.nl.leaseweb.net/debian/ jessie main contrib non-free
		EOF
		
		# Debian jessie-backports
		cat <<-EOF > ${backports_sourcelist_tmp}
		deb http://http.debian.net/debian jessie-backports main
		EOF
		
		# Debian-multimedia
		cat <<-EOF > ${multimedia_sourcelist_tmp}
		deb http://www.deb-multimedia.org jessie main non-free
		EOF
		
		# packages.libregeek.org
		cat <<-EOF > ${steamos_tools_sourcelist_tmp}
		deb http://packages.libregeek.org/SteamOS-Tools/ jessie main
		deb-src http://packages.libregeek.org/SteamOS-Tools/ jessie main
		EOF

		# move tmp var files into target locations
		sudo mv  ${sourcelist_tmp} ${sourcelist}
		sudo mv  ${multimedia_sourcelist_tmp} ${multimedia_sourcelist}
		sudo mv  ${backports_sourcelist_tmp} ${backports_sourcelist}
		sudo mv  ${steamos_tools_sourcelist_tmp} ${steamos_tools_sourcelist}
		
		# Update system
		echo -e "\n==> Updating index of packages...\n"
		sleep 2s
		sudo apt-get update
		
		echo -e "\n==> Updating keyring for deb-multimedia and updating lists [again]...\n"
		sleep 2s
		# update keyring for deb-multimedia
		sudo apt-get install deb-multimedia-keyring
		sudo apt-get update
	
		#####################################################
		# Remind user how to install
		#####################################################
		
		clear
		cat <<-EOF
		###########################################################"
		How to use"
		###########################################################"
		You can now not only install package from the SteamOS repository,
		but also from the Debian repository with either:
		
		'sudo apt-get install <package_name>'
		'sudo apt-get -t [jessie|jessie-backports|steamos-tools] install <package_name>'
		
		Warning: If the apt package manager seems to want to remove a lot
		"of packages you have already installed, be very careful about proceeding.
		
		EOF
	
	elif [[ "$install" == "no" ]]; then
		clear
		echo -e "\n==> Removing debian repositories...\n"
		sleep 2s
		
		# original files
		sudo rm -f ${sourcelist}
		sudo rm -f ${backports_sourcelist}
		sudo rm -f ${multimedia_sourcelist}
		sudo rm -f ${prefer}
		sudo rm -f ${steamosprefer}
		sudo rm -f ${steamos_tools_prefer}
		
		# backups
		sudo rm -f ${sourcelist}.bak
		sudo rm -f ${backports_sourcelist}.bak
		sudo rm -f ${multimedia_sourcelist}.bak
		sudo rm -f ${prefer}.bak
		sudo rm -f ${steamosprefer}.bak
		sudo rm -f ${steamos_tools_prefer}.bak
		
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
