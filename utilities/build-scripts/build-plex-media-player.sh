#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-plex-media-player.sh
# Script Ver:	  0.1.3-beta
# Description:  Attempts to build a deb package from Plex Media Player git source
#               PLEASE NOTE THIS SCRIPT IS NOT YET COMPLETE!
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
git_url="https://github.com/plexinc/plex-media-player"
tarball_url="https://github.com/plexinc/plex-media-player/archive/v1.0.0.5-53192cb0.tar.gz"
tarball_file=v1.0.0.5-53192cb0.tar.gz"

# package vars
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="PlexMediaPlayer"
pkgrel="1"
dist_rel="brewmaster"
maintainer="ProfessorKaos64"
provides="plexmediaplayer"
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
	debian-keyring debian-archive-keyring cmake qt4-dev-tools ninja

}

function_clone_git()
{
	
	if [[ -d "$git_dir" ]]; then
	
		echo -e "\n==Info==\nGit folder already exists! Rebuild [r] or [p] pull?\n"
		sleep 1s
		read -ep "Choice: " git_choice
		
		if [[ "$git_choice" == "p" ]]; then
			# attempt to pull the latest source first
			echo -e "\n==> Attempting git pull..."
			sleep 2s
		
			# attempt git pull, if it doesn't complete reclone
			if ! git pull; then
				
				# failure
				echo -e "\n==Info==\nGit directory pull failed. Removing and cloning..."
				sleep 2s
				rm -rf "$git_dir"
				# clone to git DIR
				git clone "$git_url" "$git_dir"
				
			fi
			
		elif [[ "$git_choice" == "r" ]]; then
			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# remove, clone, enter
			rm -rf "$git_dir"
			cd "$build_dir"
			# create and clone to git dir
			git clone "$git_url" "$git_dir"
		else
		
			echo -e "\n==Info==\nGit directory does not exist. cloning now..."
			sleep 2s
			# create and clone to git dir
			git clone "$git_url" "$git_dir"
		
		fi
	
	else
		
			echo -e "\n==Info==\nGit directory does not exist. cloning now..."
			sleep 2s
			# create and clone to current dir
			git clone "$git_url" "$git_dir"
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
	
	clear
 
	#################################################
	# Build PKG
	#################################################
	
	echo -e "\n==> Creating original tarball\n"
	sleep 2s
	
	echo -e "Use upstream tarball or git source? [tar/git]"
	sleep 0.2s
	
	read -erp "Choice: " upstream_choice
	
	if [[ "$upstream_source" == "tar" ]]
	
		# create the tarball from latest tarball creation script
		# use latest revision designated at the top of this script
		wget "${tarball_url}/${tarball_file}"
		
		# unpack tarball
		tar -xf ${pkgname}*.tar.xz
		
		# actively get pkg ver from created tarball
		pkgver=$(find . -name *.orig.tar.xz | cut -c 18-41)
		
	elif [[ "$upstream_source" == "git" ]]
	
		# clone git
		git clone "$git_url" "$git_dir"
		
		# enter git dir
		cd "$git_dir"
	
	else
	
		echo -e "\nInvalid input, exiting in 15 seconds"
		sleep 15s
		exit 1
	
	fi
	
	# enter source dir
	cd ${pkgname}*

	# grab pre-requisite package binaries due to Qt 5.6 alpha being needed
	scripts/fetch-binaries.py

	# build the package
	ninja
	
	# create the redistributable
	ninja build

	############################
	# proceed to DEB BUILD
	############################
	
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
