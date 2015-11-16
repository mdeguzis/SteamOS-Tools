#!/bin/bash

# -------------------------------------------------------------------------------
# Author:		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:		build-test-chroot.sh
# Script Ver:		0.1.7
# Description:		Builds a test Docker contain, image, or Dockerfile
#			See: http://bit.ly/1GPw9lb (Digital Ocean Wiki)
#
# Usage:		./build-test-docker.sh [OS] [release]
#			./build-test-docker.sh --help for help
#
# Docker usage: 	sudo docker [option] [command] [arguments]
# Create images:	https://wiki.debian.org/Cloud/CreateDockerImage
#			https://docs.docker.com/engine/userguide/dockerimages/
#
# -------------------------------------------------------------------------------

# TODO: arguments specification, help file, install, removal, test options.

# set dir we are
scriptdir=$(pwd)

# show help if requested or list of OS's supported
if [[ "$1" == "--help" ]]; then

	show_help
	
elif [[ "$1" == "--show-supported" ]]; then

	show_supported
	
fi

# set args
os_target="$1"
rel_target="$2"

show_help()
{
	
	cat <<-EOF
	#####################################################
	Quick usage notes:
	#####################################################
	
	To create a container:
	
	./build-test-docker [OS] [TARGET]
	./build-test-docker --list-supported
	
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

show_supported()
{
	
	cat <<-EOF
	#####################################################
	Supported OS targets and release targets:
	#####################################################
	
	OS: steamos
	Targets: alchemist, brewmaster
	
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
	sudo apt-get -y --force-yes install lxc-docker

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

create_docker()
{
	
	# create steamos docker
	# See: https://hub.docker.com/search/?q=steamos&page=1&isAutomated=0&isOfficial=0&starCount=0&pullCount=0
	
	if [[ "$os_target" == "steamos" ]]; then
	
		if [[ "$rel_target" == "alchemist" ]]; then
		
			# latest steamos tag, using container from tianon/steamos/
			# See: https://hub.docker.com/r/tianon/steamos/
			sudo docker pull tianon/steamos
			
		elif [[ "$rel_target" == "brewmaster" ]]; then
	
			:

	fi
	
}


# start main
main
#create_docker
