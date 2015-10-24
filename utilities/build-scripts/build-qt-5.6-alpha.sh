#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-qt-5.6-alpha.sh
# Script Ver:	  0.1.1
# Description:	Builds QT 5.6-alpha for specific use in building PlexMediaPlayer
#
# See:		 
# Usage:        ./build-qt-5.6-alpha.sh
# -------------------------------------------------------------------------------

#################################################
# VARS
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop

# files
qt_src_url="http://download.qt.io/development_releases/qt/"
qt_rel="5.6/5.6.0-alpha/single/"
qt_src_file="qt-everywhere-opensource-src-5.6.0-alpha.tar.gz"

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="qt-everywhere-oss"
pkgver="${pkgname}+SteamOS2"
pkgrel="1"
dist_rel="brewmaster"
maintainer="ProfessorKaos64"
provides="qt-everywhere-oss"
pkggroup="utils"
requires=""
replaces=""

# build dirs
build_dir="/home/desktop/build-${pkgname}-temp"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	
	# dependencies
	sudo apt-get install -y --force-yes libfontconfig1-dev libfreetype6-dev \
	libx11-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev \
	libx11-xcb-dev libxcb-glx0-dev
	
	# Needed if not passing -qt-xcb
	sudo apt-get install -y --force-yes libxcb-keysyms1-dev libxcb-image0-dev \
	libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync0-dev libxcb-xfixes0-dev libxcb-shape0-dev \
	libxcb-randr0-dev libxcb-render-util0-dev
	
	# Needed for qtwebengine building
	sudo apt-get install -y --force-yes libcap-dev libegl1-mesa-dev x11-xserver-utils \
	libxrandr-dev libxss-dev libxcursor-dev libxtst-dev libpci-dev libdbus-1-dev \
	libatk1.0-dev libnss3-dev re2c gperf

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
	# Build QT 5.6 alpha source (main)
	#################################################

	# install qt-5.6 alpha
	# See: http://doc.qt.io/qt-5/build-sources.html
	
 	# obtain source
	wget "${qt_src_url}/${qt_rel}"
	tar -xzvf "$qt_src_file"
	cd "qt-everywhere-opensource-src*" || exit
	
	# configure opensource version, auto-accept yes
	./configure -confirm-license -opensource
	
	# Generate build
	make
	
	# install build
	sudo make install
	
	#################################################
	# Build QT 5.6 alpha source (web engine)
	#################################################
	
	cd qtwebengine
	# Don't use the qmake from the qt4-qmake package, use the qmake of the built Qt, use the full path to it.
	# See: https://forum.qt.io/topic/49031/solved-maps-and-android/4
	../qtbase/bin/qmake
	make
	sudo make install

	#################################################
	# Build Debian package
	#################################################
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s

	# use checkinstall
	sudo checkinstall --pkgname="$pkgname" --fstrans="no" --backup="no" \
	--pkgversion="$pkgver" --pkgrelease="$pkgrel" \
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
