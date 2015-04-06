
# -----------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:		      https://github.com/ProfessorKaos64/scripts
# Scipt Name:	  vaporos-pkgs.sh
# Script Ver:	  0.1.1
# Description:	Installs useful pacakges from VaporOS 2
#	
# Usage:	      ./vaporos-pkgs.sh
# ------------------------------------------------------------------------

#####################################################"
# VaporOS bindings (controller shortcuts)
#####################################################"
# FPS + more binds from VaporOS 2
# For bindings, see: /etc/actkbd-steamos-controller.conf
if [[ ! -d "/usr/share/doc/vaporos-binds-xbox360" ]]; then
  echo "VaporOS Xbox 360 bindings not found"
	echo "Attempting to install this now."
	sleep 1s
	cd ~/Downloads
	wget https://github.com/sharkwouter/steamos-installer/blob/master/pool/main/v/vaporos-binds-xbox360/vaporos-binds-xbox360_1.0_all.deb
	sudo dpkg -i vaporos-binds-xbox360_1.0_all.deb
	cd
	if [ $? == '0' ]; then
		echo "Successfully installed 'vaporos-binds-xbox360'"
		sleep 3s
	else
		echo "Could not install 'vaporos-binds-xbox360'. Exiting..."
		sleep 3s
		exit 1
	fi
else
	echo "Found package 'vaporos-binds-xbox360'."
	sleep 0.5s
fi

