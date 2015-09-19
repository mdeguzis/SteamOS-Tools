#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	build-kodi-src.sh
# Script Ver:		0.3.5
# Description:		Attempts to build a deb package from kodi-src
#               	https://github.com/xbmc/xbmc/blob/master/docs/README.linux
#               	This is a fork of the build-deb-from-src.sh script. Due to the 
#               	amount of steps to build kodi, it was decided to have it's own 
#               	script. A deb package is built from this script. 
#
# Usage:      		./build-kodi-src.sh --cores [cpu cores]
# See Also:		https://packages.debian.org/sid/kodi
# -------------------------------------------------------------------------------

scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

###################
# global vars
###################

# set default concurrent jobs if called standalone
# set concurrent jobs to 
if [[ $scriptdir == "" && "$arg1" == "--cores" ]]; then

	cores="$arg2"
	
else

	# default to 2 cores if called from desktop-software.sh
	cores="2"
	
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

install_prereqs()
{
	clear
	echo -e "==> Assessing prerequisites for building"
	sleep 1s

	# Reminder: libshairplay-dev is only available in deb-multimedia
	
	# Swaps: (libcurl3 for libcurl-dev), (dcadec-dev, build from git)
	
	
	echo -e "\n==INFO==\nInstalling packages found in Debian repositories\n"
	sleep 1s
	
	# main packages available in Debian Jessie and SteamOS repos:
	
	sudo apt-get install autoconf automake autopoint autotools-dev cmake curl \
	default-jre gawk gperf libao-dev libasound2-dev \
	libass-dev libavahi-client-dev libavahi-common-dev libbluetooth-dev \
	libbluray-dev libboost-dev libboost-thread-dev libbz2-dev libcap-dev libcdio-dev \
	libcec-dev libcurl3 libcwiid-dev libdbus-1-dev libfontconfig-dev libfreetype6-dev \
	libfribidi-dev libgif-dev libglu1-mesa-dev \
	libiso9660-dev libjasper-dev libjpeg-dev libltdl-dev liblzo2-dev libmicrohttpd-dev \
	libmodplug-dev libmpcdec-dev libmpeg2-4-dev libmysqlclient-dev libnfs-dev libogg-dev \
	libpcre3-dev libplist-dev libpng12-dev libpng-dev libpulse-dev librtmp-dev libsdl2-dev \
	libshairplay-dev libsmbclient-dev libsqlite3-dev libssh-dev libssl-dev libswscale-dev \
	libtag1-dev libtiff-dev libtinyxml-dev libtool libudev-dev \
	libusb-dev libva-dev libvdpau-dev libvorbis-dev libxinerama-dev libxml2-dev \
	libxmu-dev libxrandr-dev libxslt1-dev libxt-dev libyajl-dev lsb-release \
	nasm python-dev python-imaging python-support swig unzip uuid-dev yasm \
	zip zlib1g-dev libglew-dev

	# When compiling frequently, it is recommended to use ccache
	sudo apt-get install ccache
	
	echo -e "\n==> Installing Kodi build dependencies sourced from ppa:team-xbmc/xbmc-ppa-build-depends\n"
	sleep 2s
	
	# origin: https://launchpad.net/~team-xbmc/+archive/ubuntu/xbmc-ppa-build-depends
	# packages are now in the packages.libregeek.org pool
	
	sudo apt-get install libcrossguid1 libcrossguid-dev dcadec1 dcadec-dev

}

main()
{
	build_dir="$HOME/kodi/"

	# If git folder exists, evaluate it
	# Avoiding a large download again is much desired.
	# If the DIR is already there, the fetch info should be intact

	if [[ -d "$build_dir" ]]; then

		echo -e "\n==Info==\nGit folder already exists! Rebuild [r] or [p] pull?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "p" ]]; then
			# attempt to pull the latest source first
			echo -e "\n==> Attempting git pull..."
			sleep 2s
			cd "$build_dir"
			# eval git status
			output=$(git pull 2> /dev/null)

			# evaluate git pull. Remove, create, and clone if it fails
			if [[ "$output" != "Already up-to-date." ]]; then

				echo -e "\n==Info==\nGit directory pull failed. Removing and cloning...\n"
				sleep 2s
				rm -rf "$build_dir"
				# create and clone to $HOME/kodi
				cd
				git clone git://github.com/xbmc/xbmc.git kodi
				# enter build dir
				cd "$build_dir"
			fi

		elif [[ "$git_choice" == "r" ]]; then
			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			sudo rm -rf "$build_dir"
			# create and clone to $HOME/kodi
			cd
			git clone git://github.com/xbmc/xbmc.git kodi
			# enter build dir
			cd "$build_dir"
		else

			echo -e "\n==Info==\nGit directory does not exist. cloning now...\n"
			sleep 2s
			# create and clone to $HOME/kodi
			cd
			git clone git://github.com/xbmc/xbmc.git kodi
			# enter build dir
			cd "$build_dir"

		fi

	else

			echo -e "\n==Info==\nGit directory does not exist. cloning now...\n"
			sleep 2s
			# create DIRS
			mkdir -p "$build_dir"
			# create and clone to current dir
			git clone git://github.com/xbmc/xbmc.git kodi
			# enter build dir
			cd "$build_dir"
	fi


	#################################################
	# Build Kodi
	#################################################

	echo -e "\n==> Building Kodi"

  	# Note (needed?):
  	# When listing the application depends, reference https://packages.debian.org/sid/kodi
  	# for an idea of what packages are needed.

	#[NOTICE] crossguid / libcrossguid-dev all Linux destributions.
        #Kodi now requires crossguid which is not available in Ubuntu
        # repositories at this time. We supply a Makefile in tools/depends/target/crossguid
        # to make it easy to install into /usr/local.

	# make -C tools/depends/target/crossguid PREFIX=/usr/local/crossguid

	# This above method has issues with using the suggested prefix /usr/local
	# use our package rebuilt from https://launchpad.net/~team-xbmc nightly
	# This package is not hosted at packages.libregeek.org

	# libdcadec
	
	# libtag
	#make -C lib/taglib
	#make -C lib/taglib install

	# libnfs
	#make -C lib/libnfs
	#make -C lib/libnfs install

  	# create the Kodi executable manually perform these steps:
	./bootstrap

	# ./configure <option1> <option2> PREFIX=<system prefix>... 
	# (See --help for available options). For now, use the default PREFIX
        # A full listing of supported options can be viewed by typing './configure --help'.
	# Default install path is:

	./configure

	# make the package
	# By adding -j<number> to the make command, you describe how many
     	# concurrent jobs will be used. So for quad-core the command is:

	# make -j4
	
	# however, we will assume here that most people at least have a dual-core
	# processor
	make -j${$cores}

	# Install Kodi
	sudo make install

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

	echo -e "\n==> Adding desktop file and artwork"

	# If called standalone change copy paths
	if [[ "$scriptdir" == "" ]]; then

		
		# copy files based of pwd
		sudo cp ../../cfgs/desktop-files/kodi.desktop "/usr/share/applications"
		sudo cp ../../artwork/banners/Kodi.png "/home/steam/Pictures"
	else

		# add desktop file for SteamOS/BPM
		sudo cp "$scriptdir/cfgs/desktop-files/kodi.desktop" "/usr/share/applications"
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

	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"


}

# start main
install_prereqs
main

