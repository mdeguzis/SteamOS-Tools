#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    		Michael DeGuzis
# Git:		    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  xephyr-test.sh
# Script Ver:		0.1.1
# Description:	Basic test with xephyr to draw a display window
#
# Usage:      	xephyr-test.sh
#               non-Steam addition of Xephyr-Test desktop shortcut
#
# See:          http://jeffskinnerbox.me/posts/2014/Apr/29/howto-using-xephyr-to-
#               create-a-new-display-in-a-window/
# -------------------------------------------------------------------------------

# pre-reqs
sudo apt-get install xephyr xnest

# Copy desktop file over for use in BPM
cp "Xephyr-Test.desktop" "/usr/share/applications"

# Xnest basic test
Xnest :3 -geometry 1280x1024+200+200 -name "Xnest Test Window" 2> /dev/null & xclock -display :3 &
sleep 1
killall Xnest

# Xephyr test
Xephyr -ac -screen 1280x1024 -br -reset -terminate 2> /dev/null :3 &
sleep 1
killall Xephyr

# test using gnome desktop
Xephyr -ac -screen 1280x1024 -br -reset -terminate 2> /dev/null :3 & \
DISPLAY=:3 gnome-session & DISPLAY=:3.0 ssh -XfC dekstop@steamos xterm
sleep 1
killall Xephyr
