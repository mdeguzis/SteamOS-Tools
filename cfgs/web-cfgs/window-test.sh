#!/bin/bash
# -------------------------------------------------------------------------------
# Author:       Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:   xephyr-test.sh
# Script Ver:   0.1.1
# Description:  Basic test with xephyr/xnest to draw a display window
#
# Usage:        xephyr-test.sh
#               non-Steam addition of Xephyr-Test desktop shortcut
#
# See:          http://jeffskinnerbox.me/posts/2014/Apr/29/howto-using-xephyr-to-
#               create-a-new-display-in-a-window/
#
# Also:         cfgs/web-cfgs/skel/Default-Launch.sh for the current implementation
# -------------------------------------------------------------------------------

# pre-reqs
# sudo apt-get install xserver-xephyr xnest xdpyinfo

# Copy desktop file over for use in BPM
# cp "Xephyr-Test.desktop" "/usr/share/applications"

###################################################################
# Informational
###################################################################

# Get current window resolution of display
WIN_RES=$(DISPLAY=:0 xdpyinfo | grep dimensions | awk '{print $2}')

###################################################################
# Test scenarios
###################################################################
WIN_RES=$(DISPLAY=:0 xdpyinfo | grep dimensions | awk '{print $2}')
COMMA_WIN_RES=$(echo $WIN_RES | awk '{sub(/x/, ","); print}')

Xephyr :15 -ac -screen 1920x1080 -fullscreen -host-cursor -once &
export DISPLAY=:15
openbox-session &
LP=$LD_PRELOAD
unset LD_PRELOAD
google-chrome http://www.youtube.com/tv#/ --kiosk --windows-size=1920,1080
export LD_PRELOAD=$LP
killall Xephyr

