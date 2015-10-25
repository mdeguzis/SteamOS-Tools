#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-cmakeer.sh
# Script Ver:	  0.1.3-beta
# Description:	  Attempts to build a deb package from Plex Media Player git source
#                 PLEASE NOTE THIS SCRIPT IS NOT YET COMPLETE!
# See:		 
# Usage:
# -------------------------------------------------------------------------------

#################################################
# VARS
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# build dirs
build_dir="/home/desktop/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

# upstream URL
git_url="https://cmake.org/cmake.git"

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="cmake"
pkgrel="1"
dist_rel="brewmaster"
maintainer="ProfessorKaos64"
provides="cmake"
pkggroup="video"
requires=""
replaces=""

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install needed packages
	sudo apt-get install git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring

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
	
	# Get upstream source
	git clone "$git_url" "$git_dir"
		
	# enter git dir
	cd "$git_dir"

	#################################################
	# Build PMP source
	#################################################

	# get desired version
	git checkout v3.1.3
	
	# configure cmake
	./configure
  
	# build the package
	make

	#################################################
	# Build Debian package
	#################################################
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s

	# use checkinstall
	sudo checkinstall --pkgname="$pkgname" --fstrans="no" --backup="no" \
	--pkgversion="$(date +%Y%m%d)+git" --pkgrelease="$pkgrel" \
	--deldoc="yes" --maintainer="$maintainer" --provides="$provides" --replaces="$replaces" \
	--pkggroup="$pkggroup" --requires="$requires" --exclude="/home"
		
	fi

	#################################################
	# Post install configuration
	#################################################
	
	# TODO
	
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
	
	if [[ -d "$git_dir/build" ]]; then
	
		echo -e "Showing contents of: $git_dir/build: \n"
		ls "$git_dir/build" | grep -E *.deb
	
	elif [[ -d "$build_dir" ]]; then
	
		echo -e "Showing contents of: $build_dir: \n"
		ls "${git_dir}/build" | grep -E *.deb

	fi

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# transfer files
		if [[ -d "$git_dir/build" ]]; then
		
			scp ${git_dir}/build/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming
		
		elif [[ -d "$build_dir" ]]; then
		
			scp $build_dir/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
