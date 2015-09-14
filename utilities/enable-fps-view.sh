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
		copy_script_content
		
	else
		
		# remove and add the latest script
		sudo rm -f /usr/bin/show-fps
		copy_script_content	
	fi
}

copy_script_content()
{

	# Set variables
	cat <<- EOF > "stats-temp.sh"
	WM="steamcompmgr"
	DEBUGOPT="-v"
	export DISPLAY=:0.0

	# Set the command used to restart steamcompmgr with fps display
	DEBUGCMD="$WM -d $DISPLAY $DEBUGOPT"

	# Get the command used to start steamcompmgr
	RUNNING=$(ps ax|grep ${WM}|head -1|cut -d":" -f2-|cut -d" " -f2-)

	# Check if debug mode is on
	if [[ ! "$RUNNING" == "$DEBUGCMD" ]]; then
        	killall ${WM}
        	${DEBUGCMD} &
	else
        	killall ${WM}
        	${WM} -d ${DISPLAY} &
	fi
	EOF
	
	# move script
	sudo mv stats-temp.sh /usr/bin/show-fps
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
