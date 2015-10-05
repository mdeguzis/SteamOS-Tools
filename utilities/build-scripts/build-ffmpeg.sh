#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-ffmpeg.sh
# Script Ver:	  0.1.1
# Description:	Attempts to build a deb package from ffmpeg git source
#               IN PROGRESS, DO NOT* USE!
#
# See:		      https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
# Usage:
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# upstream URL
git_url="https://github.com/FFmpeg/FFmpeg"

# package vars
pkgname="ffmpeg"
pkgrel="1"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"
provides="ffmpeg"
pkggroup="video"
requires=""
replaces="ffmpeg"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y install autoconf automake build-essential libass-dev libfreetype6-dev \
	libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
	libxcb-xfixes0-dev pkg-config texinfo zlib1g-dev
	
	echo -e "\n==> Installing $pkgname build dependencies...\n"
	sleep 2s
	
	### REPLACE THESE WITH PACKAGES SPECIFIED BY UPSTREAM SOURCE ###
	sudo apt-get install yasm libx264-dev cmake mercurial libmp3lame-dev \
	libopus-dev

}

main()
{
	
	# create and enter build_dir
	if [[ ! -d "$build_dir" ]]; then
	
		mkdir -p "$build_dir"
		
	else
	
		rm -rf "$build_dir"
		mkdir -p "$build_dir"
		
	fi
	
	# Enter build dir
	cd "$build_dir"
	
	clear
 
 	#################################################
	# Build libfdk-aac
	#################################################

	echo -e "\n==> Bulding libfdk-aac\n"
	sleep 2s

	wget -O fdk-aac.tar.gz https://github.com/mstorsjo/fdk-aac/tarball/master
	tar xzvf fdk-aac.tar.gz
	cd mstorsjo-fdk-aac*
	autoreconf -fiv
	./configure --prefix="$HOME/ffmpeg_build" --disable-shared
	
	if make; then

	echo -e "\n==INFO==\nlibfdk-aac build successful"
	sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\nlibfdk-aac build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
  
	#################################################
	# Build libvpx
	#################################################
	
	echo -e "\n==> Bulding libvpx\n"
	sleep 2s
  
	wget http://storage.googleapis.com/downloads.webmproject.org/releases/webm/libvpx-1.4.0.tar.bz2
	tar xjvf libvpx-1.4.0.tar.bz2
	cd libvpx-1.4.0
	PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests
	PATH="$HOME/bin:$PATH"
	
	if make; then
	
		echo -e "\n==INFO==\nlibvpx build successful"
		sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\nlibvpx build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
	
	#################################################
	# Build fmpeg
	#################################################
	
	wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
	tar xjvf ffmpeg-snapshot.tar.bz2
	cd ffmpeg
	PATH="/usr/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
	--prefix="$HOME/ffmpeg_build" \
	--pkg-config-flags="--static" \
	--extra-cflags="-I$HOME/ffmpeg_build/include" \
	--extra-ldflags="-L$HOME/ffmpeg_build/lib" \
	--bindir="/usr/bin" \
	--enable-gpl \
	--enable-libass \
	--enable-libfdk-aac \
	--enable-libfreetype \
	--enable-libmp3lame \
	--enable-libopus \
	--enable-libtheora \
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libx264 \
	--enable-libx265 \
	--enable-nonfree
	PATH="/usr/bin:$PATH"
	
	if make; then

	echo -e "\n==INFO==\nffmpeg build successful"
	sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\nffmpeg build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
 
	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package $pkgname from source\n"
	sleep 2s

	sudo checkinstall

	#################################################
	# Post install configuration
	#################################################
	
	cat <<-EOF
	Installation is now complete and ffmpeg is now ready for use. 
	Your newly compiled FFmpeg programs are in ~/bin.
	
	EOF
	
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
	
	echo -e "Showing contents of: $build_dir: \n"
	ls "$build_dir"

	echo -e "\n==> Would you like to trim tar.gz, dsc files, and folders for uploading? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " trim_choice
	
	if [[ "$trim_choice" == "y" ]]; then
		
		# cut files so we just have our deb pkg
		sudo rm -f $git_dir/*.tar.gz
		sudo rm -f $git_dir/*.dsc
		sudo rm -f $git_dir/*.changes
		sudo rm -f $git_dir/*-dbg
		sudo rm -f $git_dir/*-dev
		sudo rm -f $git_dirs/*-compat
		
		# remove source directory that was made
		find $build_dir -mindepth 1 -maxdepth 1 -type d -exec rm -r {} \;
		
	elif [[ "$trim_choice" == "n" ]]; then
	
		echo -e "File trim not requested"
	fi

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# cut files
		if -d "$build_dir"; then
			scp $build_dir/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
