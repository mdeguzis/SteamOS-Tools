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
	# cp -v scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	cp -v scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	
	# mark executable
	chmod +x /home/desktop/${target}-chroot/tmp/chroot-post-install.sh

	# Modify target based on opts
	sed -i "s|"default"|${target}|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
	
	# Change opt-in based on opts
	sed -i "s|"beta_tmp"|${beta_flag}|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
	
	# enter chroot to test
	echo -e "You will now be placed into the chroot. Press [ENTER] to continue."
	echo -e "If you wish to not run any post operations and remain with a"
	echo -e "'Stock' chroot, type 'stock' and [ENTER] instead...\N"
	echo -e "You may use '/usr/sbin/chroot /home/desktop/${target}-chroot' to manually"
	echo -e "enter the chroot."
	
	# Capture input
	read stock_choice
	
	if [[ "$stock_choice" == "\n" ]]; then
		# Captured carriage return only, continue on as normal
		printf "Continuing..."
		
	elif [[ "$stock_choice" == "stock" ]]; then
		# Modify target based on opts
		sed -i "s|"stock_tmp"|"yes"|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
	else
		# error setting opt
		echo -e "Failure to set stock opt in/out. Exiting...\n"
		exit
	fi
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "/home/desktop/${target}-chroot" /bin/bash -c "su - -c /tmp/chroot-post-install.sh"

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
