#!/bin/bash
# See: https://github.com/rdepena/node-dualshock-controller/wiki/Pairing-The-Dual-shock-3-controller-in-Linux-(Ubuntu-Debian)

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	pair-ps4-bluetooth.sh
# Script Ver:	0.1.5
# Description:	Pairs ps4 Bluetooth controller on SteamOS
# Usage:	./pair-ps4-bluetooth.sh
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

install_prereqs()
{

	clear
	
	# check for repos or faill out
	sources_check_jessie=$(sudo find /etc/apt -type f -name "jessie*.list")
        sources_check_steamos_tools=$(sudo find /etc/apt -type f -name "steamos-tools.list")

        if [[ "$sources_check_jessie" == "" || "$sources_check_steamos_tools" == "" ]]; then
                echo -e "\nSteamOS-Tools / Debian repos do not appear to be added! Exiting in 10 seconds"
                echo -e "Please use ./add-debian-repos.sh in the root directory."
                sleep 10s
                exit 1
        else
                echo -e "\nRepository checks [OK]"
        fi
	
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	
	# install basic build packages
	sudo apt-get -y --force-yes install autoconf automake build-essential pkg-config bc checkinstall \
	python-pip python python-setuptools python-dev python-pyudev bluez-tools gcc
	
	# Install python-evdev using pip
	sudo pip install evdev
	
}

show_summary()
{

	cat <<-EOF
	#####################################################
	Summary
	#####################################################
	Installation of ds4drv is now complete. The systemd service should now be running.
	To Pair your PS4 controller, please press the Share+PS button until it rapidly
	starts to flash. After about 4-8 seconds, it should change to a solid color, 
	indicating pairing completion.
	
	If you experience issues pairing now, please reboot.
	
	For full information, please see:
	https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Pairing-PS4-controllers
	
	EOF

}

main()
{
  
	echo -e "\n==> Cloning upstream source\n"
	
	git clone https://github.com/chrippa/ds4drv
	cd ds4drv
	
	echo -e "\n==> Installing ds4drv"
	
	# Install dsrvdrv
	
	echo -e "\t--Installing base files"
	sudo python setup.py install
	
	# install service
	
	echo -e "\t--Installing service file"
	sudo cp "systemd/ds4drv.service" "/lib/systemd/system/"
	
	# ds4drv's systemd service expects the binary file to be at /usr/bin
	# this install places it at /usr/local/bin, move it
	
	echo -e "\t--Correcting binary path"
	sudo mv "/usr/local/bin/ds4drv" "/usr/bin/"
	
	# enable service
	
	echo -e "\t--Enabling service ds4drv"
	sudo systemctl enable ds4drv.service
	
	echo -e "\t--Starting ervice ds4drv"
	sudo systemctl start ds4drv.service
	
	# Show summary
	sleep 3s
	show_summary
	
}

##################################################### 
# Install prereqs 
##################################################### 
install_prereqs

##################################################### 
# MAIN 
##################################################### 
main | tee log_temp.txt 

# apt cleanup
sudo apt-get autoremove

# convert log file to Unix compatible ASCII 
strings log_temp.txt > log.txt 

# strings does catch all characters that I could  
# work with, final cleanup 
sed -i 's|\[J||g' log.txt 

# remove file not needed anymore 
rm -f "log_temp.txt" 
