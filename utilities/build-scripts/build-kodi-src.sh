#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	build-kodi-src.sh
# Script Ver:		0.6.7
# Description:		Attempts to build a deb package from kodi-src
#               	https://github.com/xbmc/xbmc/blob/master/docs/README.linux
#               	This is a fork of the build-deb-from-src.sh script. Due to the 
#               	amount of steps to build kodi, it was decided to have it's own 
#               	script. A deb package is built from this script. 
#
# Usage:      		./build-kodi-src.sh --cores [cpu cores]
#			./build-kodi-src.sh --package-deb
# See Also:		https://packages.debian.org/sid/kodi
# -------------------------------------------------------------------------------

time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

# remove old log
rm -f "kodi-build-log.txt"

###################################
# global vars
###################################

# default for packaging attempts
package_deb="no"
skip_to_build="no"

# Set target
repo_target="xbmc"

# Set buld dir based on repo target to avoid recloning for different targets
if [[ "$repo_target" != "xbmc" ]]; then

	# set build dir to alternate
	build_dir="$HOME/kodi-${repo_target}"
else
	# set build dir to default
	build_dir="$HOME/kodi/"

fi

# Set Git URL
git_url="git://github.com/${repo_target}/xbmc.git"
#git_url="git://github.com/xbmc/xbmc.git"

# set default concurrent jobs if called standalone or
# called with extra_opts during 'dekstop-software install kodi-src --cores $n'

###################
# global vars
###################

# Assess build_opts from desktop-software.sh
# Allow more concurrent threads to be specified
if [[ "$build_opts" == "--cores" ]]; then

	# build_opts used from desktop-sofware.sh, set to extra_opts $n
	cores="$build_opts_arg"
	
elif [[ "$arg1" == "--cores" ]]; then

	# set cores to $arg2 when called standalone
	cores="$arg2"
	
else

	# default to 2 cores as fallback
	cores="2"
fi
	

# assess extra opts from dekstop-software.sh
if [[ "$extra_opts" == "--package-deb" || "$arg1" == "--package-deb" ]]; then

	# set package to yes if deb generation is requested
	package_deb="yes"
	
elif [[ "$extra_opts" == "--skip-build" || "$arg1" == "--skip-build" ]]; then

	# If Kodi is confirmed by user to be built already, allow build
	# to be skipped and packaging to be attempted directly
	skip_build="yes"
	package_deb="yes"
	
fi

##################################
# Informational
##################################

# Source build notes:
# https://github.com/xbmc/xbmc/blob/master/docs/README.linux

# Current version:
# https://github.com/xbmc/xbmc/blob/master/version.txt

# model control file after:
# https://packages.debian.org/sid/kodi

# Current checkinstall config:
# cfgs/source-builds/kodi-checkinstall.txt

kodi_prereqs()
{
	clear
	
	cat <<-EOF
	-----------------------------------------------------------
	Kodi-src build script
	-----------------------------------------------------------
	EOF
	
	# Main build dependencies are installed via desktop-software.sh
	# from the software list cfgs/software-lists/kodi-src.txt
	
	# required for building kodi debs
	if [[ "$package_deb" == "yes" ]]; then
	
		#####################################
		# Dependencies - Debian sourced
		#####################################
	
		echo -e "==> Installing build deps for packaging\n"
		sleep 2s
	
		sudo apt-get install -y build-essential fakeroot devscripts checkinstall \
		cowbuilder pbuilder debootstrap cvs fpc gdc libflac-dev \
		libsamplerate0-dev libgnutls28-dev
	
		echo -e "\n==> Installing build deps sourced from ppa:team-xbmc/xbmc-ppa-build-depends\n"
		sleep 2s

		#####################################
		# Dependencies - ppa:xbmc sourced
		#####################################

		# Info: packages are rebuilt on SteamOS brewmaster, and hosted at 
		# packages.libregeek.org
		
		# Origin: ppa:team-xbmc/ppa 
		sudo apt-get install -y libcec3 libcec-dev libafpclient-dev libgif-dev \
		libmp3lame-dev libgif-dev libplatform-dev
		
		# Origin: ppa:team-xbmc/xbmc-nightly
		# It seems shairplay, libshairplay* are too old in the stable ppa
		sudo apt-get install -y libshairport-dev libshairplay-dev shairplay
		
		#####################################
		# Linking
		#####################################
		
		# Not needed at the moment

	fi
}

kodi_package_deb()
{
	
	# Debian link: 	    https://wiki.debian.org/BuildingTutorial
	# Ubuntu link: 	    https://wiki.ubuntu.com/PbuilderHowto
	# XBMC/Kodi readme: https://github.com/xbmc/xbmc/blob/master/tools/Linux/packaging/README.debian
	
	# Maybe use sudo "bash -c 'cat "TEXT" >> "/etc/sudoers'""
	# These next 3 lines will need added to /etc/sudoers, if not added already
	
	# Defaults env_reset,env_keep="DIST ARCH CONCURRENCY_LEVEL"
	# Cmnd_Alias PBUILDER = /usr/sbin/pbuilder, /usr/bin/pdebuild, /usr/bin/debuild-pbuilder
	# Desktop ALL=(ALL) PBUILDER
	
	# copy pbuilder template
	# If called standalone change copy paths
	
	############################################################
	# Assess if we are to build for host/ARCH we have or target
	############################################################
	
	echo -e "Build Kodi for our host/ARCH or for target? [host|target]"
	
	# Ensure we are in the proper DIR
	cd "$build_dir"
	
	# Testing...use our fork with a different changelog setup
	
	# change address in xbmc/tools/Linux/packaging/mk-debian-package.sh
	sed -i 's|xbmc-packaging/archive/master.tar.gz|ProfessorKaos64/xbmc-packaging/archive/steamos-brewmaster.tar.gz|g' "tools/Linux/packaging/mk-debian-package.sh"
	
	# get user choice
	sleep 0.2s
	read -erp "Choice: " build_choice

	if [[ "$build_choice" == "host" ]]; then
	
		# build of the main debian build script ONLY
		tools/Linux/packaging/mk-debian-package.sh
		
	elif [[ "$build_choice" == "target" ]]; then
		
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
		
		# setup dist base
		if sudo DIST=brewmaster pbuilder create; then
		
			echo -e "\nBrewmaster environment created successfully!"
			
		else 
		
			echo -e "\nBrewmaster environment creation FAILED! Exiting in 10 seconds"
			sleep 10s
			exit 1
		fi
	
	
		# Clean xbmc pbuilder dir
		rm -rf "/home/$USER/xbmc-packaging/pbuilder"
		mkdir -p "/home/$USER/xbmc-packaging/pbuilder"
		
		# create directory for dependencies
		mkdir -p "/home/$USER/xbmc-packaging/deps"
		
		RELEASEV=16 \
		DISTS="$dist_choice" \
		ARCHS="amd64" \
		BUILDER="pdebuild" \
		PDEBUILD_OPTS="--debbuildopts \"-j4\"" \
		PBUILDER_BASE="/home/$USER/xbmc-packaging/pbuilder" \
		DPUT_TARGET="local" \
		tools/Linux/packaging/mk-debian-package.sh

	# end building
	fi

}

kodi_clone()
{
	
	echo -e "\n==> Cloning the Kodi repository:"
	echo -e "    $git_url"

	# If git folder exists, evaluate it
	# Avoiding a large download again is much desired.
	# If the DIR is already there, the fetch info should be intact

	# Skip to build attempt if requested
	if [[ "$skip_build" == "yes" ]]; then
	
		# fire off deb packaging attempt
		echo -e "\n==> Skipping build. Attempting to package existing files in ${build_dir}\n"
		sleep 2s
		cd "$build_dir"
		kodi_package_deb
		# When testing this over SSH, give some time since it will close the connection on exit1
		echo -e "\nExiting script in 20 seconds..."
		sleep 20s
		exit 1
		
	fi

	if [[ -d "$build_dir" ]]; then

		echo -e "\n==Info==\nGit folder already exists! Reclone [r] or pull [p]?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "p" ]]; then
			# attempt to pull the latest source first
			echo -e "\n==> Attempting git pull..."
			sleep 2s

			# attempt git pull, if it doesn't complete reclone
			if ! git pull; then
				
				# command failure
				echo -e "\n==Info==\nGit directory pull failed. Removing and cloning...\n"
				sleep 2s
				rm -rf "$build_dir"
				# create and clone to $HOME/kodi
				cd
				git clone $git_url ${build_dir}
				
				
			fi

		elif [[ "$git_choice" == "r" ]]; then
			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			sudo rm -rf "$build_dir"
			# create and clone to $HOME/kodi
			cd
			git clone $git_url  ${build_dir}

		else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# create and clone to $HOME/kodi
			cd
			git clone $git_url ${build_dir}

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now..."
			sleep 2s
			# create DIRS
			cd
			# create and clone to current dir
			git clone $git_url ${build_dir}

	fi

}

kodi_build()
{
	#################################################
	# Build Kodi
	#################################################

	echo -e "\n==> Building Kodi in $build_dir\n"

	# enter build dir
	cd "$build_dir"

  	# create the Kodi executable manually perform these steps:
	if ./bootstrap; then
	
		echo -e "\nBootstrap successful\n"
		
	else
	
		echo -e "\nBoostrap failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# ./configure <option1> <option2> PREFIX=<system prefix>... 
	# (See --help for available options). For now, use the default PREFIX
        # A full listing of supported options can be viewed by typing './configure --help'.
	# Default install path is:
	
	# FOR PACKAGING DEB ONLY (TESTING)
	# It may seem that per "http://forum.kodi.tv/showthread.php?tid=80754", we need to
	# export package config. 
	
	# Configure with bluray support
	# Rmove --disable-airplay --disable-airtunes, not working right now
	
	if ./configure --prefix=/usr --enable-libbluray --enable-airport; then
	
		echo -e "\nConfigured successfuly\n"
		
	else
	
		echo -e "\nConfigure failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# make the package
	# By adding -j<number> to the make command, you describe how many
     	# concurrent jobs will be used. So for quad-core the command is:

	# make -j4
	
	# Default core number is 2 if '--cores $n' argument is not specified
	if make -j${cores}; then
	
		echo -e "\nKodi built successfuly\n"
		
	else
	
		echo -e "\nBuild failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# Install Kodi if package generation is not called
	
	if [[ "$package_deb" == "no" ]]; then
	
		# install source build
		sudo make install
		
	elif [[ "$package_deb" == "yes" ]]; then
	
		echo -e "\n==> Attempting to package Kodi\n"
		sleep 3s
	
		# Attempt to build package, confirm first since buiding takes some time
		# get user choice
		echo -e "Attempting to package Kodi"
		sleep 0.3s
		
		kodi_package_deb
		
	fi

	# From v14 with commit 4090a5f a new API for binary addons is available. 
	# Not used for now ...

	# make -C tools/depends/target/binary-addons

	####################################
	# (Optional) build Kodi test suite
	####################################

	#make check

	# compile the test suite without running it

	#make testsuite

	# The test suite program can be run manually as well.
	# The name of the test suite program is 'kodi-test' and will build in the Kodi source tree.
	# To bring up the 'help' notes for the program, type the following:

	#./kodi-test --gtest_help

	#################################################
	# Post install configuration
	#################################################

}

show_summary()
{

	cat <<-EOF
	----------------------------------------------------------------
	Summary
	----------------------------------------------------------------
	Time started: ${time_stamp_start}
	Time started: ${time_stamp_end}
	Total Runtime (minutes): $runtime

	You should now be able to add Kodi as a non-Steam game in Big
	Picture Mode. Please see see the wiki for more information
	
	EOF
	sleep 2s
	
}

kodi_post_cfgs()
{
	
	echo -e "\n==> Adding desktop file and artwork"

	# If called standalone change copy paths
	if [[ "$scriptdir" == "" ]]; then

		
		# copy files based of pwd
		sudo cp ../../cfgs/desktop-files/kodi.desktop "/usr/share/applications"
		sudo cp ../../artwork/banners/Kodi.png "/home/steam/Pictures"
		
	else

		# add desktop file for SteamOS/BPM
		sudo cp "$scriptdir/cfgs/desktop-files/kodi-src.desktop" "/usr/share/applications"
		sudo cp "$scriptdir/artwork/banners/Kodi.png" "/home/steam/Pictures"
		
	fi

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# check if Kodi really installed
	if [[ -f "/usr/local/bin/kodi" ]]; then
	
		echo -e "\n==INFO==\nKodi was installed successfully."
		
	else 
	
		echo -e "\n==INFO==\nKodi install unsucessfull\n"
	
	fi
	
	
}



####################################################
# Script sequence
####################################################
# Main order of operations
main()
{
	kodi_prereqs
	kodi_clone
	kodi_build
	kodi_post_cfgs
	
}

#####################################################
# MAIN
#####################################################
main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > kodi-build-log.txt &> /dev/null

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' kodi-build-log.txt

# remove file not needed anymore
rm -f "log_temp.txt"
