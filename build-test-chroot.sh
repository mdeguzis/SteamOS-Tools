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

# Install the required packages 
apt-get install binutils debootstrap

	# Warn user script must be run as root
	if [ "$(id -u)" -ne 0 ]; then
		clear
		printf "\nScript must be run as root! Try:\n\n"
		printf "'sudo $0 install'\n\n"
		printf "OR\n"
		printf "\n'sudo $0 uninstall'\n\n"
		exit 1
	fi

if [[ "$1" == "-type" ]]; then
  if [[ "$2" == "wheezy" ]]; then
  
    # create our chroot folder
    if [[ -d "/home/desktop/wheezy-chroot" ]]; then
    
    # remove DIR
    rm -rf "/home/desktop/wheezy-chroot"
    fi
    
    # create DIR
    mkdir -p "/home/desktop/wheezy-chroot"
    
    # buildin the environment
    debootstrap --arch i386 wheezy /home/desktop/wheezy-chroot http://http.debian.net/debian
    
    # enter chroot to test
    chroot /home/desktop/wheezy-chroot
    
    # kick back if failure
    if [ $? == '0' ]; then
      echo -e "\nFailed to enter chroot. Please try again\n"
    fi
    
    # create dpkg policy for daemons
    chroot /srv/chroot/wheezy
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
    mount --bind /dev/pts /srv/chroot/wheezy/dev/pts
    
    # eliminate unecessary packages
    apt-get install deborphan
    deborphan -a
    
    # exit chroot
    exit

  elif [[ "$2" == "steamos" ]]; then
    # nothing to see here for now
    echo "" > /dev/null
  fi
fi


