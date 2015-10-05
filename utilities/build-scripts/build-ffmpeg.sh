#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-ffmpeg.sh
# Script Ver:	0.7.7
# Description:	Attempts to build a deb package from ffmpeg git source
#
# See:		https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
#		http://archive.ubuntu.com/ubuntu/pool/universe/f/ffmpeg/ffmpeg_2.5.8-0ubuntu0.15.04.1.dsc
# Usage:	build-ffmpeg.sh
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
provides="ffmpeg, qt-faststart, ffmpeg-dbg, ffmpeg-doc, libavcodec-ffmpeg56, libavcodec-ffmpeg-dev, \
libavdevice-ffmpeg56, libavdevice-ffmpeg-dev, libavfilter-ffmpeg5, libavfilter-ffmpeg-dev, \
libavformat-ffmpeg56, libavformat-ffmpeg-dev, libavresample-ffmpeg2, libavresample-ffmpeg-dev, \
libavutil-ffmpeg54, libavutil-ffmpeg-dev, libpostproc-ffmpeg53, libpostproc-ffmpeg-dev, libswresample-ffmpeg1, \
libswresample-ffmpeg-dev, libswscale-ffmpeg3, libswscale-ffmpeg-dev"
pkggroup="video"
requires=""
replaces="ffmpeg"

# set build_dir
build_dir="$HOME/build-${pkgname}-temp"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y install autoconf automake build-essential libass-dev libfreetype6-dev \
	libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
	libxcb-xfixes0-dev pkg-config texinfo zlib1g-dev bc checkinstall
	
	echo -e "\n==> Installing $pkgname build dependencies...\n"
	sleep 2s
	
	### REPLACE THESE WITH PACKAGES SPECIFIED BY UPSTREAM SOURCE ###
	sudo apt-get -y install yasm libx264-dev cmake mercurial libmp3lame-dev \
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
 
 	#################################################
	# Build libfdk-aac
	#################################################

	echo -e "\n==> Bulding libfdk-aac\n"
	sleep 3s

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
	
	# Install build and clean
	# Must be installed in order to buld ffmpeg properly
	make install
	make clean
  
	#################################################
	# Build libvpx
	#################################################
	
	echo -e "\n==> Bulding libvpx\n"
	sleep 3s
  
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
	
	# Install build and clean
	# Must be installed in order to buld ffmpeg properly
	make install
	make clean
	
	#################################################
	# Build lix265
	#################################################
	
	echo -e "\n==> Bulding libx265\n"
	sleep 3s
  	
  	git clone https://github.com/videolan/x265
	cd x265/build/linux
	PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED:bool=off ../../source

	if make; then
	
		echo -e "\n==INFO==\nlix265 build successful"
		sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\nlix265 build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
	
	# Install build and clean
	# Must be installed in order to buld ffmpeg properly
	make install
	make distclean
	
	#################################################
	# Build fmpeg
	#################################################
	
	echo -e "\n==> Bulding ffmpeg\n"
	sleep 3s
	
	wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
	tar xjvf ffmpeg-snapshot.tar.bz2
	cd ffmpeg
	PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
	  --prefix="$HOME/ffmpeg_build" \
	  --pkg-config-flags="--static" \
	  --extra-cflags="-I$HOME/ffmpeg_build/include" \
	  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
	  --bindir="$HOME/bin" \
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
	PATH="$HOME/bin:$PATH"
	
	if make; then

	echo -e "\n==INFO==\nffmpeg build successful"
	sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\nffmpeg build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
	
	# clean
	make distclean
	hash -r
 
	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package $pkgname from source\n"
	sleep 2s

	sudo checkinstall --pkgname="$pkgname" --fstrans="no" --backup="no" \
	--pkgversion="$(date +%Y%m%d)+git" --pkgrelease="$pkgrel" \
	--deldoc="yes" --maintainer="$maintainer" --provides="$provides" --replaces="$replaces" \
	--pkggroup="$pkggroup" --requires="$requires" --exclude="/home"

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
