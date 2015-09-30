
#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	       Michael DeGuzis
# Git:		         https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:   	 build-pbuilder-env.sh
# Script Ver:	     0.1.3
# Description:	   Create buld environment for testing and building packages
# Usage:	         ./build-pbuilder-env.sh [target] [arch]
#
# Notes:          For targets, see utilities/pbuilder-helper.txt
# -------------------------------------------------------------------------------

#####################################
# Dependencies
#####################################

echo -e "==> Installing depedencies for packaging and testing\n"
sleep 2s

sudo apt-get install -y build-essential fakeroot devscripts checkinstall \
cowbuilder pbuilder debootstrap cvs fpc gdc libflac-dev libsamplerate0-dev libgnutls28-dev

#####################################
# PBUILDER setup
#####################################

# ask for DIST target
	echo -e "\nEnter DIST to build for (see utilities/pbuilder-helper.txt)"
	
	# get user choice
	sleep 0.2s
	read -erp "Choice: " dist_choice

if [[ "$scriptdir" == "" ]]; then
	
	# copy files based of pwd
	touch "$HOME/.pbuilderrc"
	sudo touch "/root/.pbuilderrc"
	cp ../pbuilder-helper.txt "$HOME/.pbuilderrc"
	sudo cp ../pbuilder-helper.txt "/root/.pbuilderrc"
	
else

	# add desktop file for SteamOS/BPM
	touch "$HOME/.pbuilderrc"
	sudo touch "/root/.pbuilderrc"
	cp "$scriptdir/utilities/pbuilder-helper.txt" "$HOME/.pbuilderrc"
	sudo cp "$scriptdir/utilities/pbuilder-helper.txt" "/root/.pbuilderrc"
	
fi

#####################################
# PBUILDER environement creation
#####################################

# set vars

DISTS="$dist_choice" \
ARCHS="$arch" \
BUILDER="pdebuild" \
PBUILDER_BASE="/home/$USER/${target}-pbuilder/"

# setup dist base
if sudo pbuilder create; then

	echo -e "\n${target} environment created successfully!"
	
else 

	echo -e "\n${target} environment creation FAILED! Exiting in 15 seconds"
	sleep 15s
	exit 1
fi
	
# create directory for dependencies
mkdir -p "/home/$USER/${dist_choice}-packaging/deps"
