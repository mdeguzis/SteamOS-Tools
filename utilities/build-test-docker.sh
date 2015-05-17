#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:		      https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-test-chroot.sh
# Script Ver:	  0.1.3
# Description:	Builds a test Docker contain, image, or Dockerfile
#               See: http://bit.ly/1GPw9lb (Digital Ocean Wiki)
#
# Usage:	      ./build-test-docker.sh [options] [application] 
#		            ./build-test-docker.sh --help for help
#
# Docker usage: sudo docker [option] [command] [arguments]
#
# Warning:	    You MUST have the Debian repos added properly for
#		            Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

# TODO: arguments specification, help file, install, removal, test options.

# set dir we are
scriptdir=$(pwd)

# set args
opt1="$1"
opt2="$2"

show_help()
{
	
	cat <<-EOF
	#####################################################
	Quick usage notes:
	#####################################################
	
	To ask docker for a list of all available commands:
	
	sudo docker
	
	For a quick demo of how it works, take a look here:
	https://www.docker.com/tryit/
	
	The user guide can be found here:
	https://docs.docker.com/userguide/
	
	Enjoy!
	#####################################################
	EOF

}

main()
{
	clear
	echo -e "\n==> import verification keys\n"
	
	# The below needs replaced with gpg_import tool line under $scriptdir/utilities
	# once key is known from gpg --list-keys 
	sudo sh -c "wget -qO- https://get.docker.io/gpg | apt-key add -"
	
	#############################################################################
	# While this set of routines "works", it makes removal trickier later
	#############################################################################
	# curl -sSL https://get.docker.com/ | sed "s/|debian/|steamos|debian/g"|sh
	#############################################################################

	# Install via apt list

	# Create and add required text to preferences file
	echo -e "\n==> Set /etc/sources.list.d/docker.list"
	
	# remove list file if it exists, create if not
	if [[ -f "/etc/apt/sources.list.d/docker.list" ]]; then
		sudo rm -f "/etc/apt/sources.list.d/docker.list"
	else
		sudo touch "/etc/apt/sources.list.d/docker.list"
	fi

	echo 'echo "deb http://get.docker.io/ubuntu docker main" >> "/etc/apt/sources.list.d/docker.list"' | sudo -s
	
	echo -e "\n==> Updating system, please wait...\n"
	sleep 2s
	sudo apt-get update
	
	# install
	sudo apt-get install lxc-docker

	echo -e "\n==> Post install commands\n"
	# add user to docker group
	sudo usermod -aG docker desktop
	
	# start the docker daemon if it hasn't been already
	if [[ -f /var/run/docker.pid ]]; then
		# don't start daemon
		echo "" > /dev/null
	else
		# start docker daemon
		sudo docker -d &
	fi
	
	# show quick help
	show_help
	
	echo -e "\n==> Installation check\n"
	
	# confirm docker is installed
	install_check=$(which docker)
	
	if [[ "$install_check" == "/usr/bin/docker" ]]; then
		echo -e "Docker successfully installed!\n"
		sleep 2s
	else
		echo -e "Docker failed to install!\n"
		exit
		sleep 2s
	fi
  
}

# start main
main
