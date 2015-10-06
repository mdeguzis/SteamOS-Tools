#!/bin/bash

# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-obs-studio.sh
# Script Ver:	0.5.5
# Description:	Attempts to build a deb package from obs-studio git source
#
# See:		https://github.com/jp9000/obs-studio/wiki/Install-Instructions
# Usage:	build-obs-studio.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# upstream URL
git_url="https://github.com/jp9000/obs-studio"

# package vars
pkgname="obs-studio"
pkgrel="1"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"
provides="obs-studio"
pkggroup="utils"
requires=""
replaces="obs-studio"

# build dirs
build_dir="/home/desktop/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes libx11-dev libgl1-mesa-dev libpulse-dev libxcomposite-dev \
	libxinerama-dev libv4l-dev libudev-dev libfreetype6-dev \
	libfontconfig-dev qtbase5-dev libqt5x11extras5-dev libx264-dev \
	libxcb-xinerama0-dev libxcb-shm0-dev libjack-jackd2-dev libcurl4-openssl-dev
	
	echo -e "\n==> Installing $pkgname build dependencies...\n"
	sleep 2s
	
	# Until the ffmpeg build script is finished, install ffmpeg from rebuilt PPA source
	# hosted in the Libregeek repositories. Exit if not installed correctly.
	
	if sudo apt-get install -y --force-yes ffmpeg libavcodec-ffmpeg-dev libavdevice-ffmpeg-dev libavfilter-ffmpeg-dev \
	libavformat-ffmpeg-dev libavresample-ffmpeg-dev libavutil-ffmpeg-dev libpostproc-ffmpeg-dev \
	libswresample-ffmpeg-dev libswscale-ffmpeg-dev; then
	
		echo -e "\nFFMPEG package checcks [PASS]"
		sleep 2s
	  
	else
  
		echo -e "\nFFMPEG packages assessment [FAIL]. Exiting in 15 seconds\n"
		sleep 15s
		exit 1
    
	fi
}

main()
{
	
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
	# Clone upstream source
	#################################################

	git clone "$git_url" "$git_dir"

	#################################################
	# Build obs-studio (uses cmake)
	#################################################
  
  	echo -e "\n==> Creating $pkgname build files\n"
	sleep 2s

	# enter source
	cd "$git_dir"
  
	mkdir build && cd build || exit
	cmake -DUNIX_STRUCTURE=1 -DCMAKE_INSTALL_PREFIX=/usr ..
	make -j4

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building $pkgname Debian package from source\n"
	sleep 2s

	sudo checkinstall --pkgname="$pkgname" --fstrans="no" --backup="no" \
	--pkgversion="$(date +%Y%m%d)+git" --pkgrelease="$pkgrel" \
	--deldoc="yes" --maintainer="$maintainer" --provides="$provides" --replaces="$replaces" \
	--pkggroup="$pkggroup" --requires="$requires" --exclude="/home"

	#################################################
	# Post install configuration
	#################################################
	
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
	
	echo -e "Showing contents of: ${git_dir}/build: \n"
	ls "${git_dir}/build" | grep -E *.deb

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# cut files
		if [[ -d "${git_dir}/build" ]]; then
			scp ${git_dir}/build/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
