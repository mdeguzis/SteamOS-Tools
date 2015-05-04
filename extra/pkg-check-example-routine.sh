#!/bin/bash

# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		pkg-check-example-routine.sh
# Script Ver:	  	0.1.1
# Description:		Example script to check Debian pkgs for other routines
#
#See:            	https://wiki.debian.org/HowToPackageForDebian
#Usage:	      	  ./pkg-check-example-routine.sh
#
# -------------------------------------------------------------------------------

m_install_retroarch()
{

	#####################################################
	# Retroarch (imported 20150503)
	#####################################################
	
	# VARs (All examples)
	# A small package called antimirco will me used, then removed later
	PKG="antimicro"
	PKG_FILENAME="antimicro_2.5_SteamOS_amd64.deb"
	BASE_URL="http://www.libregeek.org/SteamOS-Extra/emulation"
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
	
	# proceed to eval routine
	m_pkg_routine_eval

}

m_pkg_routine_eval()
{

	#####################################################
	# Info:
	#####################################################
	# This routine uses VARs set in each emulator 
	# sub-function to process the emulator package through
	# routine evals.
		
	# start PKG routine
	if [[ "$PKG_OK" == "" && "$apt_mode" != "remove" ]]; then
	
		echo -e "\n==INFO==\n$PKG not found. Installing now...\n"
		sleep 2s
		wget -P /tmp "$BASE_URL/$PKG_FILENAME"
		sudo gdebi "/tmp/$PKG_FILENAME"
		# cleanup
		rm -f "/tmp/$PKG_FILENAME"
		
		if [ $? == '0' ]; then
			echo -e "\n==INFO==\nSuccessfully installed $PKG"
			sleep 2s
		else
			echo -e "\n==INFO==\nCould not install $PKG. Exiting..."
			sleep 3s
			exit 1
		fi
		
	elif [ "$apt_mode" == "remove" ]; then
		# user requested removal
		echo -e "\n==> Removal requested for $PKG\n"
		sleep 2s
		sudo apt-get remove $PKG
	else
		echo "Checking for $PKG [OK]"
		sleep 0.5s
	
	# end PKG routine
	fi	
	
}

m_emulation_install_main()
{
	
	# kick off emulation installs here or comment them out 
	# to disable them temporarily.
	
	# Install Example pkg:
	m_install_antimicro
	
	# remove example package
	echo -e "\n==> Removing example pkg $PKG..."
	sleep 2s
	sudo apt-get remove antimicro

}
