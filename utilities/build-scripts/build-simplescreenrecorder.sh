#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-simplescreenrecorder.sh
# Script Ver:	1.0.0
# Description:	Attempts to build a deb package from simplescreenrecorder git source
#
# See:		https://launchpadlibrarian.net/219136562/simplescreenrecorder_2.19.3-1~vivid1.dsc
# Usage:	build-simplescreenrecorder.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# upstream URL
git_url="https://github.com/MaartenBaert/ssr"

# package vars
pkgname="simplescreenrecorder"
pkgrel="1"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"
provides="simplescreenrecorder"
pkggroup="X11"
requires=""
replaces="simplescreenrecorder"

# set build_dir
build_dir="$HOME/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get -y install autoconf automake build-essential pkg-config bc checkinstall
	
	echo -e "\n==> Installing $pkgname build dependencies...\n"
	sleep 2s
	
	### REPLACE THESE WITH PACKAGES SPECIFIED BY UPSTREAM SOURCE ###
	sudo apt-get install -y g++ cmake libqt4-dev libsdl1.2-dev libxi-dev libxtst-dev \
	libsdl2-dev libX11-dev

}

function_clone_git()
{
	
	echo -e "\n==> Cloning upstream git source"
	sleep 2s
	
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
			# remove, clone
			rm -rf "$git_dir"
			# clone to git DIR
			git clone "$git_url" "$git_dir"
		else
		
			echo -e "\n==Info==\nGit directory does not exist. cloning now..."
			sleep 2s
			# clone to git DIR
			git clone "$git_url" "$git_dir"
		
		fi
	
	else
		
			echo -e "\n==Info==\nGit directory does not exist. cloning now..."
			sleep 2s
			# clone to git DIR
			git clone "$git_url" "$git_dir"
	fi
	
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
	
	# install prereqs for build
	install_prereqs
	
	# Clone upstream source code
	function_clone_git
	
	# Enter git dir for build
	cd "$git_dir" || exit
 
	#################################################
	# Build simplescreenrecorder
	#################################################
	
	echo -e "\n==> Bulding ${pkgname}\n"
	sleep 3s
	
	# Creaste build files
	mkdir build && cd build
	cmake ..
  	
	# make package, fail out if incomplete
	if make; then

  	echo -e "\n==INFO==\n${pkgname} build successful"
  	sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\n${pkgname}build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
 
	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
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
		cd "$scriptdir" || exit
	else
		cd "$HOME" || exit
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: ${build_dir}/build: \n"
	ls ${git_dir}/build | grep -E *.deb

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice
	
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
main
