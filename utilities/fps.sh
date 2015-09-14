#!/bin/bash

# Set variables
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
