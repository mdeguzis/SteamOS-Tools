#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Script Ver:	1.3.3
# Description:	Configures LibreGeek repositories
#
# Usage:	./configure-repos.sh
# Opts:		See "--help"
# ------------------------------------------------------------------------------

ARG1="$1"

# Set default arg if none is set
if [[ "${ARG1}" == "" ]]; then

	ARG1="--default"
	
fi

function_repair_setup()
{

	echo -e "\n==> Repairing repository configurations\n"
	sleep 2s

	BETA_LIST="/etc/apt/sources.list/steamos-tools-beta.list"
	BETA_PREFS="/etc/apt/preferences.d/steamos-tools-beta"

	# See if we have a beta repository, so it is retained
	if [[ "${BETA_LIST}" != "" || "${BETA_PREFS}" != "" ]]; then

		# If either file is present, assume beta was added or is now broken
		BETA_REPO="true"

	fi

	# Clear out packages
	sudo apt-get purge -y steamos-tools-repo libregeek-archive-keyring steamos-tools-beta-repo

	files="jessie jessie-backports steamos-tools steamos-tools-beta"

	for file in ${files};
	do

		sudo rm -rf /etc/apt/sources.list.d/${file}*
		sudo rm -rf /etc/apt/preferences.d/${file}*

	done

	# Comment out any non SteamOS source lines that are not already commented out
	# Backup file for safety
	# Original file: https://gist.github.com/ProfessorKaos64/085ad37c7d23b9a1141c4d6268416205
	# Updated 20161117
	sudo sed -i.bak '/steamos/! s/^#*/#/!' "/etc/apt/sources.list"
	echo -e "\nNotice: /etc/apt/sources.list backup saved as /etc/apt/sources.list.bak\n"

}

function_repo_setup()
{

	if [[ "${INSTALL}" = "true" ]]; then

		# Add main configuration set

		echo -e "\n==> Adding keyrings and repository configurations\n"
		sleep 2s

		wget http://packages.libregeek.org/libregeek-archive-keyring-latest.deb -q --show-progress -nc
		wget http://packages.libregeek.org/steamos-tools-repo-latest.deb -q --show-progress -nc
		sudo dpkg -i libregeek-archive-keyring-latest.deb
		sudo dpkg -i steamos-tools-repo-latest.deb
		sudo apt-get install -y debian-archive-keyring
	
		# If beta repo is requested

		if [[ "${BETA_REPO}" = "true" ]]; then

			echo -e "\n==> Adding additional beta repository\n"
			sleep 2s
			wget http://packages.libregeek.org/steamos-tools-beta-repo-latest.deb -q --show-progress -nc
			sudo dpkg -i steamos-tools-beta-repo-latest.deb

		fi

	elif [[ "${INSTALL}" = "false" ]]; then

		echo -e "\n==> Removing all repository setups and keyrings.\n"
		sleep 2s

		sudo apt-get purge -y steamos-tools-beta-repo steamos-tools-repo libregeek-archive-keyring

	fi

}

function_debian_only()
{

	if [[ "${INSTALL}" = "true" ]]; then

		echo -e "\n==> Adding Debian repository\n"
		sleep 2s
		wget http://packages.libregeek.org/debian-repo-latest.deb -q --show-progress -nc
		sudo dpkg -i debian-repo-latest.deb

	elif [[ "${INSTALL}" = "false" ]]; then

		echo -e "\n==> Removing Debian repository setup.\n"
		sleep 2s
		sudo apt-get purge -y debian-repo

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
	rm -f debian-repo-latest.deb

}

function_help()
{

	clear

	cat<<- EOF
	==================================================================
	Available options
	==================================================================

	--default			Normal installation
	--debian-only			Add only Debian sources
	--repair			Repair and install setup
	--enable-testing		Add testing repository
	--remove			Remove all repository setups
	--remove-testing		Remove just beta repository setup

	EOF

}

main()
{
	
	# Process options or exit if an incorrect option is called

	case "${ARG1}" in

		--help)
		# Just show help
		function_help
		exit
		;;

		--default)
		# Process just default setup
		INSTALL="true"
		function_repo_setup
		function_cleanup
		;;

		--debian-only)
		# Process just debian setup
		INSTALL="true"
		function_debian_only
		function_cleanup
		;;

		--repair)
		# reapair setup and process normally
		INSTALL="true"
		function_repair_setup
		function_repo_setup
		function_cleanup
		;;

		--enable-testing)
		# Default + testings
		INSTALL="true"
		BETA_REPO="true"
		function_repo_setup
		function_cleanup
		;;
		
		--remove)
		# process removal
		INSTALL="false"
		function_repo_setup
		function_cleanup
		;;

		--remove-testing)
		# process remove for beta setup
		INSTALL="false"
		function_repo_setup
		function_cleanup
		;;

		*)
		# invalid option, exit
		echo -e "Invalid option! Exiting..."
		sleep 2s
		exit
		;;

	esac

}

# Start script
main
