#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-deb-from-PPA.sh
# Script Ver:	0.1.3
# Description:	Attempts to build a deb package from a git src
#
# Usage:	sudo ./build-deb-from-src.sh
#		source ./build-deb-from-src.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./build-deb-from-src.sh
	./build-deb-from-src.sh --help
	source ./build-deb-from-src.sh
	
	The third option, preeceded by 'source' will 
	execute the script in the context of the calling 
	shell and preserve vars for the next run.
	
	EOF
}

if [[ "$arg" == "--help" ]]; then
	#show help
	show_help
	exit
fi

install_prereqs()
{
	clear
	echo -e "\n==>Installing pre-requisites for building...\n"
	sleep 1s
	# install needed packages
	sudo apt-get install devscripts build-essential

}

main()
{
	build_dir="/home/desktop/build-deb-temp"
	git_dir="$build_dir/git-temp"
	
	clear
	# remove contents* of previous dir, if they exist
	# We want to keep git-temp/ for subsequent pulls
	if [[ -d "$build_dir" ]]; then
		sudo rm -rf "$build_dir/*"
	fi
	
	# create build dir and git dir, enter it
	mkdir -p "$git_dir"
	cd "$build_dir"
	
	# Ask user for repos / vars
	echo -e "==> Please enter or paste the git URL now:"
	echo -e "[ENTER to use last: $git_url]\n"
	
	# set tmp var for last run, if exists
	git_url_tmp="$git_url"
	if [[ "$git_url" == "" ]]; then
		# var blank this run, get input
		read -ep "Git source URL: " git_url
	else
		read -ep "Git source URL: " git_url
		# user chose to keep var value from last
		if [[ "$git_url" == "" ]]; then
			git_url="$git_url_tmp"
		else
			# keep user choice
			git_url="$git_url"
		fi
	fi
	
	# If git folder exists, evaluate it
	# Avoiding a large download again is much desired.
	# If the DIR is already there, the fetch info should be intact
	
	if [[ -d "$git_dir" ]]; then
	
		echo -e "\n==Info==\nGit folder already exists! Attempting git pull...\n"
		sleep 1s
		# attempt to pull the latest source first
		cd "$git_dir"
		# eval git status
		output=$(git pull 2> /dev/null)
		
		# evaluate git pull. Remove, create, and clone if it fails
		if [[ "$output" != "Already up-to-date." ]]; then

			echo -e "\n==Info==\nGit directory pull failed. Removing and cloning...\n"
			sleep 2s
			rm -rf "$git_dir"
			mkdir -p "$git_dir"
			cd "$git_dir"
			# clone to current DIR
			git clone "$git_url" .
		fi
			
	else
		
			echo -e "\n==Info==\nGit directory does not exist. cloning now...\n"
			sleep 2s
			# create and clone to current dir
			git clone "$git_url" .
			
	fi
	
 
	#################################################
	# Build PKG
	#################################################
	
	# Output readme via less to review build notes first
	echo -e "\n==> Opening any available README.md to review build notes..."
	sleep 2s
	less README.md
	
	# Ask user to enter build commands until "done" is received
	echo -e "\nPlease enter your build commands, pressing [ENTER] after each one."
	echo -e "When finished, please enter the word 'done' without quotes\n"
	sleep 0.5s
	
	while [[ "$src_cmd" != "done" ]];
	do
		# capture command
		read -ep "Build CMD: " src_cmd
		
		# Execute src cmd
		$src_cmd
	done
  
	############################
	# proceed to DEB BUILD
	############################
	
	echo -e "\n==> Building Debian package from source"
	
	# build deb package
	sleep 2s
	dpkg-buildpackage -us -uc

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
	echo -e "\n###################################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you do not, please check build dependcy errors listed above."
	echo -e "cd $build_dir"
	echo -e "cd $build_folder"
	echo -e "###################################################################\n"
	
	echo -e "Showing contents of: $build_dir:"
	ls "$build_dir"
	cat "$git_dir"

}

# start main
main

