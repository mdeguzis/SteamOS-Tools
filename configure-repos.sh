#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Script Ver:	1.3.2
# Description:	Configures LibreGeek repositories
#
# Usage:	./configure-repos.sh
# Opts:		See "--help"
# ------------------------------------------------------------------------------

arg1="$1"

# Set default arg if none is set
if [[ "${arg1}" == "" ]]; then

	arg1="--default"
	
fi

function_repair_setup()
{

	echo -e "\n==> Repairing repository configurations\n"
	sleep 2s

	# Clear out packages
	sudo apt-get purge -y steamos-tools-repo libregeek-archive-keyring steamos-tools-beta-repo

	files="jessie jessie-backports steamos-tools steamos-tools-beta"

	for file in ${files};
	do

		sudo rm -rf /etc/apt/sources.list.d/${file}*
		sudo rm -rf /etc/apt/preferences.d/${file}*

	done

	# Ensure there isn't a custom repo in main configuration file
	sudo sed -i '/libregeek/d' "/etc/apt/sources.list"

}

function_default_setup()
{

	if [[ "${install}" = "true" ]]; then

		# Add main configuration set

		echo -e "\n==> Adding keyrings and repository configurations\n"
		sleep 2s

		wget http://packages.libregeek.org/libregeek-archive-keyring-latest.deb -q --show-progress -nc
		wget http://packages.libregeek.org/steamos-tools-repo-latest.deb -q --show-progress -nc
		sudo dpkg -i libregeek-archive-keyring-latest.deb
		sudo dpkg -i steamos-tools-repo-latest.deb
		sudo apt-get install -y debian-archive-keyring

	elif [[ "${install}" = "false" ]]; then

		echo -e "\n==> Removing all repository setups.\n"
		sleep 2s

		sudo apt-get purge -y steamos-tools-beta-repo steamos-tools-repo

	fi

}

function_beta_setup()
{

	if [[ "${install}" = "true" ]]; then

		echo -e "\n==> Adding additional beta repository\n"
		sleep 2s
		wget http://packages.libregeek.org/steamos-tools-beta-repo-latest.deb -q --show-progress
		sudo dpkg -i steamos-tools-beta-repo-latest.deb

	elif [[ "${install}" = "false" ]]; then

		echo -e "\n==> Removing beta repository setup.\n"
		sleep 2s
		sudo apt-get purge -y steamos-tools-beta-repo

	fi

}

function_cleanup()
{

	echo -e "\n==> Updating system\n"
	sleep 2s

	sudo apt-get update -y

	echo -e "\n==> Cleaning up\n"

	rm -f libregeek-archive-keyring-latest.deb
	rm -f steamos-tools-beta-repo-latest.deb
	rm -f steamos-tools-repo-latest.deb

}

function_help()
{

	clear

	cat<<- EOF
	==================================================================
	Available options
	==================================================================

	--default			Normal installation
	--repair			Repair and install setup
	--enable-testing		Add testing repository
	--remove			Remove all repository setups
	--remove-testing		Remove just beta repository setup

	EOF

}

main()
{
	
	# Process options or exit if an incorrect option is called

	case "${arg1}" in

		--help)
		# Just show help
		function_help
		break
		;;

		--default)
		# Process just default setup
		install="true"
		function_default_setup
		function_cleanup
		;;

		--repair)
		# reapair setup and process normally
		install="true"
		function_repair_setup
		function_default_setup
		function_cleanup
		;;

		--enable-testing)
		# Default + testings
		install="true"
		function_default_setup
		function_beta_setup
		function_cleanup
		;;
		
		--remove)
		# process removal
		install="false"
		function_default_setup
		function_cleanup
		;;

		--remove-testing)
		# process remove for beta setup
		install="false"
		function_beta_setup
		function_cleanup
		;;

		*)
		# invalid option, exit
		echo -e "Invalid option! Exiting..."
		sleep 2s
		break
		;;

	esac

}

# Start script
main
