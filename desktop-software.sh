#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	0.3.5
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value.
#
# Usage:	./desktop-software.sh [option] [type]
# Options:	[install|uninstall|list] 
# Types:	[basic|extra|emulation|<pkg_name>]
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

funct_vars()
{
	# Set vars
	options="$1"
	type="$2"
	apt_mode="install"
	uninstall="no"
}

funct_import_modules()
{
	
	# pull in modules for script
	source "scriptmodules/emu-from-source.sh"
	
}

show_help()
{
	
	clear
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	You have two options with this script:
	
	Basic
	---------------------------------------------------------------
	Standard Debian desktop application loadout.
	Based on: http://distrowatch.com/table.php?distribution=debian
	
	Extra
	---------------------------------------------------------------
	Extra software
	Based on feeback and personal preference.
	
	<pkg_name> 
	---------------------------------------------------------------
	Any package you wish to specify yourself. Alchemist repos will be
	used first, followed by Debian Wheezy.
	
	For a complete list, type:
	'./debian-software list [basic|extra]'
	
	Install with:
	'./debian-software [install|uninstall|list] [basic|extra|<pkg_name>]'
	
	Press enter to continue...
	EOF
	
	read -n 1
	printf "Continuing...\n"
	clear

}

# Show help if requested

if [[ "$1" == "--help" ]]; then
        show_help
	exit 0
fi

funct_pre_req_checks()
{
	
	# Adding repositories
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' python-software-properties | grep "install ok installed")
	
	if [ "" == "$PKG_OK" ]; then
		echo -e "python-software-properties not found. Setting up python-software-properties.\n"
		sleep 1s
		sudo apt-get install -t wheezy python-software-properties
	else
		echo "Checking for python-software-properties: [Ok]"
		sleep 0.2s
	fi
	
}

get_software_type()
{
	
	# set software type
        if [[ "$type" == "basic" ]]; then
                # add basic software to temp list
                software_list="cfgs/basic-software.txt"
        elif [[ "$type" == "extra" ]]; then
                # add full softare to temp list
                software_list="cfgs/extra-software.txt"
        elif [[ "$type" == "emulation" ]]; then
                # add emulation softare to temp list
                software_list="cfgs/emulation.txt"
        elif [[ "$type" == "$type" ]]; then
                # install based on $2 string response
                software_list=$(echo $type)
        fi
	
}

add_repos()
{

	# set software type
        if [[ "$type" == "basic" ]]; then
                # non-required for now
                echo "" > /dev/null
        elif [[ "$type" == "extra" ]]; then
                # non-required for now
                echo "" > /dev/null
        elif [[ "$type" == "emulation" ]]; then
                # retroarch
                echo "" > /dev/null
        elif [[ "$type" == "$type" ]]; then
                # non-required for now
                echo "" > /dev/null
        fi
	
}

install_software()
{
	# For a list of Debian software pacakges, please see:
	# https://packages.debian.org/search?keywords=wheezy

	clear
	# Set mode and proceed based on main() choice
        if [[ "$options" == "uninstall" ]]; then
                apt_mode="remove"
	else
		apt_mode="install"
        fi
        
        # Update keys and system first
        echo -e "\nUpdating system, please wait...\n"
	sleep 1s
        sudo apt-key update
        sudo apt-get update

	# create alternate cache dir in /home/desktop due to the 
	# limited size of the default /var/cache/apt/archives size
	
	mkdir -p "/home/desktop/cache_temp"
	# create cache command
	cache_tmp=$(echo "-o dir::cache::archives="/home/desktop/cache_temp"")
	
	# Inform user of preliminary action
	echo -e "\n\nAttempting package installations from Alchemist...\n"
	sleep 2s
	
	# Install from Alchemist first, Wheezy as backup
	for i in `cat $software_list`; do
		sudo apt-get $cache_tmp $apt_mode $i 2> /dev/null
	done 
	
	# Packages that fail to install, use Wheezy repositories
	if [ $? == '0' ]; then
		echo -e "\nSuccessfully installed software from Alchemist repo!\n" 
	else
		echo -e "\nCould not install all packages from Alchemist repo, trying Wheezy...\n"
		sleep 2s
		sudo apt-get $cache_tmp -t wheezy $apt_mode `cat $software_list`
		
		if [ $? == '0' ]; then
			echo -e "\nCould not install all packages. Please check errors displayed"
			echo -e "\nor run 'sudo ./install-debian-software [option] [type] &> log.txt\n"
			sleep 3s
			# halt script
			exit
		fi
	fi
	####################################################################
	
	# If software type was for emulation, continue building
	# emulators from source (DISABLE FOR NOW)
	
        if [[ "$type" == "emulation" ]]; then
                # call external build script
                #efs_main
                echo "" > /dev/null
	fi
	
}

show_warning()
{

        clear
        printf "\nWarning: usage of this script is at your own risk!\n\n"
        printf "\nIn order to run this script, you MUST have had enabled the Debian\n"
        printf "repositories! If you wish to exit, please press CTRL+C now..."
        printf "\n\n type './debian-software --help' for assistance.\n"

        read -n 1
        printf "Continuing...\n"
        sleep 1s
}

main()
{

        # generate software listing based on type
        get_software_type

	if [[ "$type" == "basic" ]]; then

		if [[ "$options" == "uninstall" ]]; then
        		uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/basic-software.txt
                        clear
                        cat $software_list | less
			exit
		fi

		show_warning
		install_software

	elif [[ "$type" == "extra" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/extra-software.txt
                        clear
			cat $software_list | less
			exit
                fi
                
                show_warning
		install_software
                
        elif [[ "$type" == "emulation" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/emulation.txt
                        clear
			cat $software_list | less
			exit
                fi
                
                show_warning
		install_software
                
        elif [[ "$type" == "$type" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # no list to show
                        clear
			echo -e "No listing for $type \n"
			exit
                fi

		show_warning
		install_software
	fi
}

#handle prerequisite software
funct_import_modules
funct_vars
funct_pre_req_checks
add_repos

# Start main function
main
