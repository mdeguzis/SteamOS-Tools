#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      gameplay-recording.shsh
# Script Ver:	      0.0.1
# Description:	    Record gameplay from SteamOS runngin BPM with and Xbox 
#                   360 gamepad.
#
# See/Source:       goo.gl/pi24cK [Steam Community]
# Usage:	          N/A called from main desktop-software script
#
# Warning:	        You MUST have the Debian repos added properly for
#	                  Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# set default scriptdir
scriptdir="/home/desktop/SteamOS-Tools"


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

# we want to append this to the controller file as to not upset an existing
# setup, such as a previously added xb360 bindings.
# Ask user anyway to confirm

if [[ -f "/etc/actkbd-steamos-controller.conf" ]]; then
  
  echo -e "\nExiting custom controller assignments already found!"
  echo -e "Showing the existing file..."
  less "/etc/actkbd-steamos-controller.conf"
  echo -e "\n(r)eplace or (a)append our changes?"
  
  # get user input
  read -ep "Choice: " mapping_choice
  
  if [[ "$mapping_choice" == "r" ]]
    
    # copy over file that exists
    sudo cp "$scriptdir/cfgs/recording/actkbd-steamos-controller.conf" \
    "/etc/actkbd-steamos-controller.conf"
  
  elif [[ "$mapping_choice" == "a" ]]
  
    # append instead
    cat "$scriptdir/cfgs/recording/actkbd-steamos-controller.conf" \
    | sudo tee --append "/etc/actkbd-steamos-controller.conf"
  
  else
   
    # default is to keep
    echo -e "Invalid input detected, keeping existing file and appending!"
    cat "$scriptdir/cfgs/recording/actkbd-steamos-controller.conf" \
    | sudo tee --append "/etc/actkbd-steamos-controller.conf"
  
  fi

############################################
# Configure
############################################

sudo chmod +x "/usr/local/bin/recording-stop"
sudo chmod +x "/usr/local/bin/recording-start"
