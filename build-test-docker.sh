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

# set args
opt1="$1"
opt2="$2"

funct_set_vars()
{
	reponame=$(echo "docker")
	prefer=$(echo "/etc/apt/preferences.d/${reponame}.list")

}

show_help()
{
	
	cat <<-EOF
	#####################################################
	Quick usage notes:
	#####################################################
	
	Docker is now installed. 
	To ask docker for a list of all available commands:
	
	sudo docker
	
	For a quick demo of how it works, take a look here:
	https://www.docker.com/tryit/
	
	The user guide can be found here:
	https://docs.docker.com/userguide/
	
	Enjoy!
	
	EOF
	
	echo ""
}

main()
{
	clear
	echo -e "\n==> import verification keys\n"
	sudo sh -c "wget -qO- https://get.docker.io/gpg | apt-key add -"
	
	#############################################################################
	# While this set of routines "works", it makes removal trickier later
	#############################################################################
	# echo -e "\n==> Obtaining Docker\n"
	# mkdir -p "/home/desktop/docker-testing"
	# cd "/home/desktop/docker-testing/"
	# curl -sSL https://get.docker.com/ | sed "s/|debian/|steamos|debian/g"|sh
	#############################################################################

	# Install via apt list
	
	# Create and add required text to preferences file
	echo -e "\n==> Set /apt/preferences.d"
	
	sudo bash -c 'cat <<-EOF >> $prefer
	deb http://get.docker.io/ubuntu docker main
	EOF'
	
	exit
	
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

# setup
funct_set_vars

# start main
main
