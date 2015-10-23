#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-mpv.sh
# Script Ver:	  0.1.1
# Description:	Builds mpv for specific use in building PlexMediaPlayer
#
# See:		 
# Usage:        ./build-mpv.sh
# -------------------------------------------------------------------------------

#################################################
# VARS
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="mpv"
pkgver="${pkgname}+SteamOS2"
pkgrel="1"
dist_rel="brewmaster"
maintainer="ProfessorKaos64"
provides="mpv"
pkggroup="video"
requires=""
replaces=""

# build dirs
build_dir="/home/desktop/build-${pkgname}-temp"

# deps
# Use the build-wrapper instead of the main mpv source
# See: https://github.com/mpv-player/mpv/blob/master/README.md
git_url="https://github.com/mpv-player/mpv-build"
git_dir="mpv-build"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	
	# dependencies
	sudo apt-get install -y --force-yes build-essential git pkg-config samba-dev \
	luajit devscripts equivs
}

main()
{
	clear
	
	#################################################
	# Fetch source
	#################################################
	
	# create and enter build_dir
	if [[ -d "$build_dir" ]]; then
	
		sudo rm -rf "$build_dir"
		mkdir -p "$build_dir"
		
	else

		mkdir -p "$build_dir"
		
	fi
	
	# Enter build dir
	cd "$build_dir"

	#################################################
	# Build mpv-build deps pkg and install
	#################################################

	# clone
	git clone "$git_url" "$git_dir"
	cd "$git_dir"
	
	# check for updates
	./update
	
	# Install the dependencies 
	rm -f mpv-build-deps_*_*.deb
	sudo mk-build-deps
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s
	
	# build debian package
	dpkg-buildpackage -uc -us -b -j4
	
	# move build-dep package to build dir
	# the mpv player package itself will be in the build dir
	mv mpv-build-deps*.deb ..
	
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

	
	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)
	
	# back out of build temp to script dir if called from git clone
	if [[ "$scriptdir" != "" ]]; then
		cd "$scriptdir"
	else
		cd "$HOME"
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	if [[ -d "$build_dir" ]]; then
	
		echo -e "Showing contents of: $build_dir: \n"
		ls "$build_dir" | grep -E *.deb

	fi

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		scp $build_dir/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

	fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
