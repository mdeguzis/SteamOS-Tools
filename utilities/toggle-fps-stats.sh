#!/bin/bash

# Thank you to Vapors/Sharkwouter
# This script will toggle steamcompmgr overlay FPS stats

# Set variables
WM="steamcompmgr"
DEBUGOPT="-v"
export DISPLAY=:0.0

# Set the command used to restart steamcompmgr with fps display
DEBUGCMD="sudo -u steam $WM -d $DISPLAY $DEBUGOPT"

# Get the command used to start steamcompmgr
RUNNING=$(ps ax|grep ${WM}|head -1|cut -d":" -f2-|cut -d" " -f2-)

# Check if debug mode is on
if [[ ! "$RUNNING" == "$DEBUGCMD" ]]; then
        sudo killall ${WM}
        ${DEBUGCMD} &
else
        sudo killall ${WM}
        sudo -u steam ${WM} -d ${DISPLAY} &
fi
