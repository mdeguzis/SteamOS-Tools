#!/bin/bash
# ----------------------------------------------------------------------------
# Author: 		Sharkwouter, http://steamcommunity.com/id/sharkwouter
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:		show-fps.sh
# Script Ver:		1.0.0
# Description:		Toggles FPS stats using steamcompmgr in verbose mode
#			Please note, this is only necessary for Brewmaster,
#			As vaporos-binds works via gamepad on Alchemist
#
# Usage:		./show-fps.sh
#
# -----------------------------------------------------------------------------

# copy script to /usr/bin and exit for first run

check_exist()
{
	if [[ ! -f "/usr/bin/show-fps" ]]; then

		# copy in latest script
		clear
		sudo cp fps.sh /usr/bin/show-fps
		
	else
		
		# remove and add the latest script
		sudo rm -f /usr/bin/show-fps
		sudo cp fps.sh /usr/bin/show-fps
	fi
}


main()
{

	# check for script
	check_exist

	# run script
	sudo runuser -l steam -c  '/usr/bin/show-fps'
}

# script flow
main
