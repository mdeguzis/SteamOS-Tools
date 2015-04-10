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
	apt-get install binutils debootstrap debian-archive-keyring dchroot
	
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
		gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --recv-keys 7DEEB7438ADDD96
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
	/usr/sbin/debootstrap --arch i386 ${release} /home/desktop/${target}-chroot ${target_URL}
	
	# enter chroot to test
	echo -e "\nYou will now be placed into the chroot."
	echo -e "Be sure to type 'exit' to continue configuration presets"
	echo -e "Hit CTRL+C after entering the chroot for a basic setup..."
	echo -e "Press enter to continue...\n"
	
	# Capture input
	read -n 1 
	printf "Continuing...\n" 
	sleep 1s
	
	/usr/sbin/chroot "/home/desktop/${target}-chroot"
	
	# pass to ensure we are in the chroot 
	#if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
	#	echo "We are chrooted!"
	#	sleep 2s
	#	exit
	#else
	#	echo -e "\nchroot entry failed. Exiting...\n"
	#	sleep 2s
	#	exit
	#fi
	
	# opt into beta in chroot if flag is thrown
	if [[ "$beta_flag" == "yes" ]]; then
		# add beta repo and update
		apt-get install steamos-beta-repo -y
		apt-get update
		apt-get upgrade
	elif [[ "$beta_flag" == "no" ]]; then
		# do nothing
		echo "" > /dev/null
	fi
	
	# create dpkg policy for daemons
	chroot /home/desktop/${target}
	cat > ./usr/sbin/policy-rc.d <<-EOF
	#!/bin/sh
	exit 101
	EOF
	chmod a+x ./usr/sbin/policy-rc.d
	
	# Several packages depend upon ischroot for determining correct 
	# behavior in a chroot and will operate incorrectly during upgrades if it is not fixed.
	dpkg-divert --divert /usr/bin/ischroot.debianutils --rename /usr/bin/ischroot
	
	if [[ -f "/usr/bin/ischroot" ]]; then
		# remove link
		/usr/bin/ischroot
	else
		ln -s /bin/true /usr/bin/ischroot
	fi
	
	# "bind" /dev/pts
	mount --bind /dev/pts /home/desktop/${target}-chroot/dev/pts
	
	# eliminate unecessary packages
	apt-get -t wheezy install deborphan
	deborphan -a
	
	# exit chroot
	echo -e "\nExiting chroot!\n"
	sleep 2s
	exit
	
}

# Routines
main()
{

	funct_prereqs
	funct_set_target
	funct_create_chroot
	
}

# start main
main
