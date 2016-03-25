#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Script Ver:	1.0.0
# Description:	Configures LibreGeek repositories
#
# Usage:	./configure-repos.sh
# Opts:		[ --testing | --remove-testing ]
#		Adds or removes testing. Please see README.md
# ------------------------------------------------------------------------------

arg1="$1"

echo -e "\n==> Adding keyrings and repository configurations\n"
sleep 2s

wget http://packages.libregeek.org/libregeek-archive-keyring-latest.deb -q --show-progress -nc
wget http://packages.libregeek.org/steamos-tools-repo-latest.deb -q --show-progress -nc
sudo dpkg -i libregeek-archive-keyring-latest.deb
sudo dpkg -i steamos-tools-repo-latest.deb
sudo apt-get install -y debian-archive-keyring

if [[ "$arg1" == "--testing" ]]; then

	echo -e "\n==> Adding additional beta repository\n"
	sleep 2s
	wget http://packages.libregeek.org/steamos-tools-beta-repo-latest.deb -q --show-progress
	sudo dpkg -i steamos-tools-beta-repo-latest.deb

elif [[ "$arg1" == "--remove-testing" ]]; then

	echo -e "\n==> Removing additional beta repository\n"
	sleep 2s
	sudo apt-get purge -y steamos-tools-beta-repo

fi

echo -e "\n==> Updating system\n"
sleep 2s

sudo apt-get update

echo -e "\n==> Cleaning up\n"

rm -f libregeek-archive-keyring-latest.deb
rm -f steamos-tools-beta-repo-latest.deb
rm -f steamos-tools-repo-latest.deb
