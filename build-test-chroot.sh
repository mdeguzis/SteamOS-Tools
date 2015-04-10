#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.1.1
# Description:	Builds a Debian Wheezy chroot for testing purposes
#               Posibly will become an option to install a SteamOS chroot
#               See: https://wiki.debian.org/chroot
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

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
	apt-get install binutils debootstrap debian-archive-keyring
	
}

funct_set_target()
{

	if [[ "$1" == "-type" ]]; then
	  if [[ "$2" == "wheezy" ]]; then
	  	target="wheezy"
	  	release="wheezy"
	  	target_URL="http://http.debian.net/debian"
	  elif [[ "$2" == "steamos" ]]; then
		target="steamos"
		release="alchemist"
		target_URL="http://http.repo.steampowered.com/steamos"
	    
	  fi
	fi
	
}

fucnt_create_chroot()
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
	fi
	
	# create DIR
	mkdir -p "/home/desktop/${target}-chroot"
	
	# buildin the environment
	/usr/sbin/debootstrap --arch i386 ${release} /home/desktop/${target}-chroot ${target_URL}
	
	# enter chroot to test
	chroot /home/desktop/${target}-chroot
	
	# kick back if failure
	if [ $? == '0' ]; then
	echo -e "\nFailed to enter chroot. Please try again\n"
	fi
	
	# create dpkg policy for daemons
	chroot /srv/chroot/${target}
	cat > ./usr/sbin/policy-rc.d <<-EOF
	#!/bin/sh
	exit 101
	EOF
	chmod a+x ./usr/sbin/policy-rc.d
	
	# Several packages depend upon ischroot for determining correct 
	# behavior in a chroot and will operate incorrectly during upgrades if it is not fixed.
	dpkg-divert --divert /usr/bin/ischroot.debianutils --rename /usr/bin/ischroot
	ln -s /bin/true /usr/bin/ischroot
	
	# "bind" /dev/pts
	mount --bind /dev/pts /home/desktop/${target}-chroot/dev/pts
	
	# eliminate unecessary packages
	apt-get install deborphan
	deborphan -a
	
	# exit chroot
	exit
	
}

# Routines
funct_prereqs
funct_set_target
fucnt_create_chroot
