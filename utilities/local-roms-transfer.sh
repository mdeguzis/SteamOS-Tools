#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	    	Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		local-rom-transfer.sh
# Script Ver: 		0.1.1
# Description:		This script dumps ROMs or files over local
#
# Usage:	      	./local-rom-transfer.sh
#			./local-rom-transfer.sh --help
#			source ./local-rom-transfer.sh
# ------------------------------------------------------------------------

arg="$1"

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./local-rom-transfer.sh
	./local-rom-transfer.sh --help
	source ./local-rom-transfer.sh
	
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

local_transfer_roms()
{
	
	clear
	
	# set start dir
	start_dir="$PWD"
	
	echo -e "\n==> Enter source path user for ROMS/Files:"
	echo -e "[ENTER to use last: $loc_path]"
	
	# set tmp var for last run, if exists
	loc_path_tmp="$loc_path"
	if [[ "$loc_path" == "" ]]; then
		# var blank this run, get input
		echo ""
		read -ep ">> " loc_path
	else
		echo ""
		read -ep ">> " loc_path
		# user chose to keep var value from last
		if [[ "$loc_path" == "" ]]; then
			loc_path="$loc_path_tmp"
		else
			# keep user choice
			loc_path="$loc_path"
		fi
	fi
	
	echo -e "\n==> Enter dest path user for ROMS/Files: "
	echo -e "Type default to use the default /home/steam/ROMs DIR"
	echo -e "[ENTER to use last: $loc_path]"
	
	# set tmp var for last run, if exists
	dest_path_tmp="$dest_path"
	if [[ "$dest_path" == "" ]]; then
		# var blank this run, get input
		echo ""
		read -ep ">> " dest_path
		
		# set default path if entered
		if [[ "$dest_path" == "default" ]]; then
			dest_path="/home/steam/ROMs"
		fi
		
	else
		echo ""
		read -ep ">> " dest_path
		# user chose to keep var value from last
		if [[ "$dest_path" == "" ]]; then
			dest_path="$dest_path_tmp"
		else
			# keep user choice
			dest_path="$dest_path"
		fi
	fi

	# Show remote list first
	echo -e "\n==> Showing listing of source dir first...press q to quit listing\n"
	sleep 2s
	
	ls $loc_path | less
	
	# enter dir for tab completion of DIR/FIle
	cd $loc_path
	
	echo -e "\nEnter target ROM DIR to copy"
	echo -e "[ENTER to last: $target_dir]:"
	echo -e "(use quotes on any single DIR name with spaces)"

	# set tmp var for last run, if exists
	target_dir_tmp="$target_dir"
	if [[ "$target_dir" == "" ]]; then
		# var blank this run, get input
		echo ""
		read -ep ">> " target_dir
	else
		echo ""
		read -ep ">> " target_dir
		# user chose to keep var value from last
		if [[ "$target_dir" == "" ]]; then
			remote_dir="$target_dir_tmp"
		else
			# keep user choice
			target_dir="$target_dir"
		fi
	fi

	# set globbed path
	# We need to keep the backslash
	# example in bash ... t="Neo\ Geo" && s=$(echo $t) && echo $s
	# target_dir=$(echo $target_dir)
	
	loc_user=$(echo $USER)
	
	echo -e "==> Copying ROMs, please wait...\n"
	sleep 1s
	
	# execute
	
	echo ""
	# determine if target dir is a file or directory
	if [[ -d "$target_dir" ]]; then
		# copy entire dir
		sudo cp -r $target_dir/ $dest_path
	else
		# copy file
		sudo cp $target_dir/ $dest_path
	fi
	echo ""
	
	# cleanup
	echo -e "\n==> Cleaning up directory permissions\n"
	if [[ "$loc_user" == "desktop" ]]; then
		sudo chown -R desktop:desktop "$ROM_DIR"
		sudo chmod -R 755 "$ROM_DIR"
	elif [[ "$loc_user" == "steam" ]]; then
		sudo chown -R steam:steam "$ROM_DIR"
		sudo chmod -R 755 "$ROM_DIR"
	fi
	
	# return to start dir
	cd "$start_dir"
	
}

# Start script
local_transfer_roms

