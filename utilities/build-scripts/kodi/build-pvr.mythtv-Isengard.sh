#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-pvr.mythtv-Isengard.sh
# Script Ver:	  0.1.1
# Description:	  Attempts to build a deb package for Kodi addon: mythtv
#
# See:		  https://launchpad.net/~team-xbmc/+archive/ubuntu/ppa/
# Usage:	  build-pvr.mythtv-Isengard.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# vars for package
pkgname="pcsx2.snapshot"
#pkgver="20151003+git"
pkgrev="1"
dist_rel="brewmaster"

# build dirs
build_dir="/home/desktop/build-pcsx2-temp"
git_dir="$build_dir/pcsx2"
git_url="https://github.com/PCSX2/pcsx2"

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install needed packages
	sudo apt-get install -y --force-yes git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring cmake g++ g++-multilib \
	libqt4-dev libqt4-dev libxi-dev libxtst-dev libX11-dev bc libsdl2-dev \
	gcc gcc-multilib nano
	
	echo -e "\n==> Installing pcsx2 build dependencies...\n"
	sleep 2s
	
	sudo apt-get install -y --force-yes libaio-dev libpng++-dev libsoundtouch-dev \
	libwxbase3.0-dev libwxgtk3.0-dev portaudio19-dev

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
	
	clear
 
	#################################################
	# Build PKG
	#################################################
	
	echo -e "\n==> Creating original tarball\n"
	sleep 2s
	
	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script
	wget "https://github.com/PCSX2/pcsx2/raw/master/debian-packager/create_built_tarball.sh"
	sh "create_built_tarball.sh"
	rm "create_built_tarball.sh"
	
	# unpack tarball
	tar -xf pcsx2*.tar.xz
	
	# actively get pkg ver from created tarball
	pkgver=$(find . -name *.orig.tar.xz | cut -c 18-41)
	
	# enter source dir
	cd pcsx2*
	
	# create the debian folder from the exiting debian-packager
	cp -r debian-packager debian
	
	# copy debian shell changelog from SteamOS-Tools
	cp "$scriptdir/$pkgname/debian/changelog" "debian/changelog"
	
	# Change version, uploader, insert change log comments
	sed -i "s|version_placeholder|$pkgver-$pkgrev|g" debian/changelog
	sed -i "s|uploader|$uploader|g" debian/changelog
	sed -i "s|dist_rel|$dist_rel|g" debian/changelog
	
	# open debian/changelog and update
	echo -e "\n==> Opening changelog for build. Please ensure there is a revision number"
	sleep 3s
	nano debian/changelog

	############################
	# proceed to DEB BUILD
	############################
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s

	# Build with dpkg-buildpackage
	
	#dpkg-buildpackage -us -uc -nc
	dpkg-buildpackage -rfakeroot -us -uc

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
		if [[ -d "$build_dir" ]]; then
			scp $build_dir/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
install_prereqs
main
