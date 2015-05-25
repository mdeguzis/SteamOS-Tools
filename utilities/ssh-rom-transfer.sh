#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	    	Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		ssh-rom-transfer.sh
# Script Ver: 		0.1.1
# Description:		This script dumps ROMs or files over SSH
#
# Usage:		./ssh-rom-transfer.sh
#			./ssh-rom-transfer.sh --help
#			source ./ssh-rom-transfer.sh
# ------------------------------------------------------------------------

arg="$1"

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./ssh-rom-transfer.sh
	./ssh-rom-transfer.sh --help
	source ./ssh-rom-transfer.sh
	
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

ssh_transfer_roms()
{
	

	# prereqs
	clear
	# Adding repositories
	PKG="openssh-server"
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
	
	if [ "" == "$PKG_OK" ]; then
		echo -e "$PKG not found. Setting up $PKG."
		sleep 1s
		sudo apt-get install $PKG
	else
		echo -e "Checking for $PKG [Ok]"
		sleep 0.2s
	fi

	echo -e "\n==> Enter local user for ROMS/Files (deskop/steam):"
	echo -e "    [ENTER to use last: $loc_user]"
	
	# set tmp var for last run, if exists
	loc_user_tmp="$loc_user"
	if [[ "$loc_user" == "" ]]; then
		# var blank this run, get input
		read loc_user
	else
		read loc_user
		# user chose to keep var value from last
		if [[ "$loc_user" == "" ]]; then
			loc_user="$loc_user_tmp"
		else
			# keep user choice
			loc_user="$loc_user"
		fi
	fi

	echo -e "\n==> Enter Remote User: "
	echo -e "    [ENTER to use last: $user]"
	
	# set tmp var for last run, if exists
	user_tmp_tmp="$user"
	if [[ "$user" == "" ]]; then
		# var blank this run, get input
		read user
	else
		read user
		# user chose to keep var value from last
		if [[ "$user" == "" ]]; then
			user="$user_tmp"
		else
			# keep user choice
			user="$user"
		fi
	fi

	echo -e "\n==> Enter remote hostname: "
	echo -e "    [ENTER to use last: $host]"
	# set tmp var for last run, if exists
	host_tmp="$host"
	if [[ "$host" == "" ]]; then
		# var blank this run, get input
		read host
	else
		read host
		# user chose to keep var value from last
		if [[ "$host" == "" ]]; then
			host="$host_tmp"
		else
			# keep user choice
			host="$host"
		fi
	fi

	echo -e "\n==> Enter remote DIR: "
	echo -e "    [ENTER to use last: $remote_dir]:"
	echo -e "    (use quotes on any single DIR name with spaces)"
	# set tmp var for last run, if exists
	remote_dir_tmp="$remote_dir"
	if [[ "$remote_dir" == "" ]]; then
		# var blank this run, get input
		read remote_dir
	else
		read remote_dir
		# user chose to keep var value from last
		if [[ "$remote_dir" == "" ]]; then
			remote_dir="$remote_dir_tmp"
		else
			# keep user choice
			remote_dir="$remote_dir"
		fi
	fi

	# Show remote list first
	echo -e "\n==> Showing remote listing first...press q to quit listing\n"
	sleep 2s
	
	ssh ${user}@${host} ls ${remote_dir} | less
	
	echo -e "\nEnter target ROM DIR to copy "
	echo -e "    [ENTER to last: $target_dir]:"
	echo -e "    (use quotes on any single DIR name with spaces)"
	# set tmp var for last run, if exists
	target_dir_tmp="$target_dir"
	if [[ "$target_dir" == "" ]]; then
		# var blank this run, get input
		read target_dir
	else
		read target_dir
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
	
	# Set ROM DIR based on local user
	if [[ "$loc_user" == "desktop" ]]; then
		ROM_DIR="/home/desktop/ROMs"
	elif [[ "$loc_user" == "steam" ]]; then
		ROM_DIR="/home/steam/ROMs"
	fi
	
	# copy ROMs
	echo -e "\n==> Executing CMD: sudo scp -r $user@$host:'$remote_dir/$target_dir' $ROM_DIR"
	sleep 1s
	
	# set cmd
	CMD=$(echo "sudo scp -r $user@$host:'$remote_dir/$target_dir' $ROM_DIR")
	
	# execute
	echo ""
	$CMD
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
	
}

# Start script
ssh_transfer_roms


