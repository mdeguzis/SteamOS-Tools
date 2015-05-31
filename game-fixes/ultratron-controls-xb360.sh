#!/bin/bash

# -----------------------------------------------------------------------
# Author:       	Michael DeGuzis
# Git:		        https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:   	ultratron-controls-xb360.sh
# Script Ver:	    0.1.1
# Description:	  This script corrects the incorrectly mapped controls
#                 for the game "Ultratron."
#
# Usage:	        ./ultratron-controls-xb360.sh
# ------------------------------------------------------------------------

clear

# vars
config_file="/home/steam/.ultratron_3.03/controls.txt"
config_file_tmp="/tmp/controls.txt"

# backup old file
echo -e "\n==> Backup up old controls file to controls.bak\n"
sudo cp $config_file $config_file.bak

cat <<-EOF > $config_file_tmp
  #Contoller configuyration
  controller2.axis.4=fireaxis
  controller2.button.7=start
  controller2.axis.4=aimX
  controller2.button.6=back
  controller2.axis.5=aimY
  controller2.button.5=action
  controller2.button.4=firebutton
  controller2.axis.1=moveX
  controller2.axis.2=moveY
  controller2=device1
  controller1=device0
  controller1.axis.4=fireaxis
  controller1.button.7=start
  controller1.axis.4=aimX
  controller1.button.6=back
  controller1.axis.5=aimY
  controller1.button.5=action
  controller1.button.4=firebutton
  controller1.axis.1=moveX
  controller1.axis.2=moveY
  device0=Generic X-Box pad
  device1=Generic X-Box pad
EOF

# move tmp file
sudo mv /tmp/controls.txt $config_file

# Ensure permissions and owner are correct
sudo chmod 611 $config_file
sudo chown steam:steam $config_file
