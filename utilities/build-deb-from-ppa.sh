#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-deb-from-PPA.sh
# Script Ver:	0.3.2
# Description:	Attempts to build a deb package from a PPA
#
# See:		If you are building from Ubuntu main, check the website
#		http://www.debianadmin.com/adding-ubuntu-repositories.html
#
# See also:	Generate a source list: http://repogen.simplylinux.ch/
#		Command 'rmadison' from devscripts to see arch's
#		Command 'apt-cache madison <PKG>'
#
# Usage:	sudo ./build-deb-from-PPA.sh
#		source ./build-deb-from-PPA.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./build-deb-from-PPA.sh
	./build-deb-from-PPA.sh --help
	source ./build-deb-from-PPA.sh
	
	The third option, preeceded by 'source' will 
	execute the script in the context of the calling 
	shell and preserve vars for the next run.
	
	IF you the message:
	WARNING: The following packages cannot be authenticated!...
	Look above in the output for apt-get update. You will see a
	line for 'NO_PUBKEY 3B4FE6ACC0B21F32'. Import this key string
	by issuing 'gpg_import.sh <key>' from the extra DIR of this repo.
	
	EOF
}

if [[ "$arg1" == "--help" ]]; then
	#show help
	show_help
	exit
fi

install_prereqs()
{

	clear
	# set scriptdir
	scriptdir="$HOME/SteamOS-Tools"
	
	echo -e "==> Checking for Debian sources..."
	
	# check for repos
	sources_check=$(sudo find /etc/apt -type f -name "jessie*.list")
	
	if [[ "$sources_check" == "" ]]; then
                echo -e "\n==INFO==\nSources do *NOT* appear to be added at first glance. Adding now...\n"
                sleep 2s
                "$scriptdir/add-debian-repos.sh"
        else
                echo -e "\n==INFO==\nJessie sources appear to be added.\n"
                sleep 2s
        fi
	
	echo -e "\n==> Installing pre-requisites for building...\n"
	
	sleep 1s
	# install needed packages
	sudo apt-get install git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring cmake

}

main()
{
	
	build_dir="/home/desktop/build-deb-temp"
	
	# remove previous dirs if they exist
	if [[ -d "$build_dir" ]]; then
		sudo rm -rf "$build_dir"
	fi
	
	# create build dir and enter it
	mkdir -p "$build_dir"
	cd "$build_dir"
	
	# Ask user for repos / vars
	echo -e "\n==> Please enter or paste the deb-src URL now:"
	echo -e "    [Press ENTER to use last: $repo_src]\n"
	
	# Of course, main Ubuntu packages are not "PPA's" so example deb-src lines are:
	# deb-src http://archive.ubuntu.com/ubuntu trusty main restricted universe multiverse
	# GPG-key(s): 437D05B5, C0B21F32
	
	# set tmp var for last run, if exists
	repo_src_tmp="$repo_src"
	if [[ "$repo_src" == "" ]]; then
		# var blank this run, get input
		read -ep "deb-src URL: " repo_src
	else
		read -ep "deb-src URL: " repo_src
		# user chose to keep var value from last
		if [[ "$repo_src" == "" ]]; then
			repo_src="$repo_src_tmp"
		else
			# keep user choice
			repo_src="$repo_src"
		fi
	fi
	
	echo -e "\n==> Please enter or paste the GPG key for this repo now:"
	echo -e "    [Press ENTER to use last: $gpg_pub_key]\n"
	gpg_pub_key_tmp="$gpg_pub_key"
	if [[ "$gpg_pub_key" == "" ]]; then
		# var blank this run, get input
		read -ep "GPG Public Key: " gpg_pub_key
	else
		read -ep "GPG Public Key: " gpg_pub_key
		# user chose to keep var value from last
		if [[ "$gpg_pub_key" == "" ]]; then
			gpg_pub_key="$gpg_pub_key_tmp"
		else
			# keep user choice
			gpg_pub_key="$gpg_pub_key"
		fi
	fi
	
	echo -e "\n==> Please enter or paste the desired package name now:"
	echo -e "    [Press ENTER to use last: $target]\n"
	target_tmp="$target"
	if [[ "$target" == "" ]]; then
		# var blank this run, get input
		read -ep "Package Name: " target
	else
		read -ep "Package Name: " target
		# user chose to keep var value from last
		if [[ "$target" == "" ]]; then
			target="$target_tmp"
		else
			# keep user choice
			target="$target"
		fi
	fi
	
	# prechecks
	echo -e "\n==> Attempting to add source list"
	sleep 2s
	
	# check for existance of target, backup if it exists
	if [[ -f /etc/apt/sources.list.d/${target}.list ]]; then
		echo -e "\n==> Backing up ${target}.list to ${target}.list.bak"
		sudo mv "/etc/apt/sources.list.d/${target}.list" "/etc/apt/sources.list.d/${target}.list.bak"
	fi
	
	# add source to sources.list.d/
	echo ${repo_src} > "${target}.list.tmp"
	sudo mv "${target}.list.tmp" "/etc/apt/sources.list.d/${target}.list"
	
	echo -e "\n==> Adding GPG key:\n"
	sleep 2s
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $gpg_pub_key
	#"$scriptdir/utilities.sh ${gpg_pub_key}"
	
	echo -e "\n==> Updating system package listings...\n"
	sleep 2s
	sudo apt-key update
	sudo apt-get update
	
	# Attempt to build target
	echo -e "\n==> Attempting to build ${target}:\n"
	sleep 2s
	apt-get source --build ${target}
	
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
	echo -e "You could also try manually building outside of this script with"
	echo -e "the following commands (at your own risk!)\n"
	echo -e "cd $build_dir"
	echo -e "cd $build_folder"
	echo -e "sudo dpkg-buildpackage -b -d -uc"
	echo -e "###################################################################\n"
	
	ls "/home/desktop/build-deb-temp"
	
	echo -e "\n==> Would you like to trim out the tar.gz and dsc files for uploading? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " trim_choice
	
	if [[ "$trim_choice" == "y" ]]; then
		
		# cut files so we just have our deb pkg
		rm -f $build_dir/*.tar.gz
		rm -f $build_dir/*.dsc
		rm -f $build_dir/*.changes
		rm -f $build_dir/*-dbg
		rm -f $build_dir/*-dev
		rm -f $build_dir/*-compat
		
	elif [[ "$trim_choice" == "n" ]]; then
	
		echo -e "File trim not requested"
	fi

	echo -e "\n==> Would you like to upload any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " upload_choice
	
	if [[ "$upload_choice" == "y" ]]; then
	
		# cut files
		"$scriptdir/extra/upload-pkg-to-libregeek.sh"
		echo -e "\n"
		
	elif [[ "$upload_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi
	
	echo -e "\n==> Would you like to purge this source list addition? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " purge_choice
	
	if [[ "$purge_choice" == "y" ]]; then
	
		# remove list
		sudo rm -f /etc/apt/sources.list.d/${target}.list
		sudo apt-get update
		
	elif [[ "$purge_choice" == "n" ]]; then
	
		echo -e "Purge not requested\n"
	fi

	
}

#prereqs
install_prereqs

# start main
main
