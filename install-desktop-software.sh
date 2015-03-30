#!/bin/bash

# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	0.1.2
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value
#
# Usage:	./steamos-stats.sh -type [basic|full]
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# ------------------------------------------------------------------------

# Set vars
response="$1"
options="$2"
apt_mode="install"
uninstall="no"

show_help()
{

clear
cat << EOF
You have two options with this script:

Basic
------------------------------------------------------------
standard debian desktop utilities: archive roller (TODO)

Full
------------------------------------------------------------
Extra software, such as libreoffice (TODO)

For a complete list, type:
'./install-debian-software --list | less'

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

basic_software()
{

	# Set mode and proceed based on main() choice
        if [[ "$options" == "uninstall" ]]; then
                apt_mode="remove"
	else
		apt_mode="install"
        fi

	# Alchemist repos
	# None here for now

	# Wheezy-only software
	sudo apt-get -t wheezy $apt_mode \
	gparted \
	baobab

}

main()
{

	# Set default vars
	type="basic"

	clear
	printf "\nIn order to run this script, you MUST have had enabled the Debian\n"
	printf "repositories! If you wish to exit, please press CTRL+C now..."
	printf "\n\n type './install-debian-software --help' for assistance.\n"

	read -n 1
	printf "Continuing...\n"
	sleep 1s

	if [[ "$response" == "basic" ]]; then
		basic_software
		if [[ "$options" == "uninstall" ]]; then
        		uninstall="yes"
		else
                	# Nothing to see here for now
                	echo /dev/null
		fi
	elif [[ "$reponse" == "full" ]]; then
    		full_software
		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"
                else
                        # Nothing to see here for now
                        echo /dev/null
                fi
	fi

}

# Start main function
main
