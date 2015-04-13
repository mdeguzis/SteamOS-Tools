#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.1.3
# Description:	Builds a Debian Wheezy / SteamOS chroot for testing 
#		purposes
#               See: https://wiki.debian.org/chroot
# Usage:	sudo ./build-test-chroot.sh -type [debian|steamos]
#		sudo ./build-test-chroot.sh --help for help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

# set arguments
opt1=$1
opt2=$2

show_help()
{
	
	clear
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	
	Usage
	---------------------------------------------------------------
	'sudo ./build-test-chroot.sh -type [debian|steamos]'
	EOF
	exit
	
}

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then
	clear
	printf "\nScript must be run as root! Try:\n\n"
	printf "'sudo $0 install'\n\n"
	printf "OR\n"
	printf "\n'sudo $0 uninstall'\n\n"
	exit 1
fi

funct_prereqs()
{
	
	# Install the required packages 
	apt-get install binutils debootstrap debian-archive-keyring -y
	
}

funct_set_target()
{

	if [[ "$opt1" == "-type" ]]; then
	  if [[ "$opt2" == "wheezy" ]]; then
	  
	  	target="debian"
	  	release="wheezy"
	  	target_URL="http://http.debian.net/debian"
	  	beta_flag="no"
	  	
	  elif [[ "$opt2" == "steamos" ]]; then
		
		target="steamos"
		release="alchemist"
		target_URL="http://repo.steampowered.com/steamos"
		beta_flag="no"
	    
	  elif [[ "$opt2" == "steamos-beta" ]]; then
		
		target="steamos-beta"
		release="alchemist"
		target_URL="http://repo.steampowered.com/steamos"
		beta_flag="yes"
	    
	  fi
	  
	elif [[ "$opt1" == "--help" ]]; then
		show_help
	fi
	
}

funct_create_chroot()
{
	if [[ "$target" == "steamos" ]]; then
		if [[ "$release" == "alchemist" ]]; then
		# import GPG key
		gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --recv-keys 7DEEB7438ABDDD96
		fi
	fi
	
	# create our chroot folder
	if [[ -d "/home/desktop/${target}-chroot" ]]; then
		# remove DIR
		rm -rf "/home/desktop/${target}-chroot"
	else
		mkdir -p "/home/desktop/${target}-chroot"
	fi
	
	# build the environment
	echo -e "\nBuilding chroot environment...\n"
	sleep 1s
	/usr/sbin/debootstrap --arch i386 ${release} /home/desktop/${target}-chroot ${target_URL}
	
	# copy over post install script for execution
	#cp -v scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	cp -v scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	
	# mark executable
	chmod +x /home/desktop/${target}-chroot/tmp/chroot-post-install.sh
	
	# change default target in script for post processing
	# this will fire off commands specific to our chroot we are building
	sed -i 's|tmp_target|${target}|g' /home/desktop/${target}-chroot/tmp/chroot-post-install.sh
	
	# EXIT FOR NOW to test the above
	echo "exiting for testing!"
	
	# enter chroot to test
	echo -e "\nYou will now be placed into the chroot."
	echo -e "Be sure to type 'exit' to quit."
	
	# Capture input
	read -n 1 
	printf "Continuing..." 
	sleep 1s
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "/home/desktop/${target}-chroot" /bin/bash -c "su - -c /tmp/test-${target}.sh"

	
}

# Routines
main()
{
	clear
	funct_prereqs
	funct_set_target
	funct_create_chroot
	
}

# start main
main
