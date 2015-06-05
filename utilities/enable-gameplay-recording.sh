#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      record-gameplay.sh
# Script Ver:	      0.0.1
# Description:	    Record gameplay from SteamOS runngin BPM with and Xbox 
#                   360 gamepad.
#
# See/Source:       goo.gl/pi24cK [Steam Community]
# Usage:	          ./record-gameplay.sh
#
# Warning:	        You MUST have the Debian repos added properly for
#	                  Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# set default scriptdir
scriptdir="/home/desktop/SteamOS-Tools"

show_help()
{
  
  clear
  echo -e "Usage:\n"
  echo -e "./record-gameplay.sh [install|uninstall]"
  echo -e "./record-gameplay.sh -help\n"
  exit 1
}

main()
{
  
  clear
  
  ############################################
  # Prerequisite packages
  ############################################
  
  echo -e "==> Checking for prerequisite packages"
  
  sudo apt-get install libav-tools libx264-123 
  
  ############################################
  # Required files
  ############################################
  
  # Pull in files for recording from cfgs/recording
  
  sudo cp "$scriptdir/cfgs/recording/recording-start" "/usr/local/bin"
  sudo cp "$scriptdir/cfgs/recording/recording-stop" "/usr/local/bin"
  sudo cp "$scriptdir/cfgs/recording/99-actkbd-controller.rules" "/etc/udev/rules.d"
  sudo cp "$scriptdir/cfgs/recording/actkbd-steamos-controller.conf" "/etc"
  
  ############################################
  # Configure
  ############################################
  
  sudo chmod +x "/usr/local/bin/recording-stop"
  sudo chmod +x "/usr/local/bin/recording-start"
  
}
