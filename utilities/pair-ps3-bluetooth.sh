#!/bin/bash
# See: https://github.com/rdepena/node-dualshock-controller/wiki/Pairing-The-Dual-shock-3-controller-in-Linux-(Ubuntu-Debian)

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	pair-ps3-bluetooth.sh
# Script Ver:	0.8.1
# Description:	Pairs PS3 Bluetooth controller on SteamOS
# Usage:	./pair-ps3-bluetooth.sh
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

install_prereqs()
{

	echo -e "\n==> Installing prerequisite software\n"
	sleep 1s

	# Fetch what has to be installed from the Debian / Valve repositories
	sudo apt-get -y install libbluetooth-dev libusb-dev bluez-tools bluez-firmware \
	bluez-hcidump checkinstall joystick pyqt4-dev-tools
	
	# Libregeek packages
	sudo apt-get -y install qtsixa
	
	# for some reason, /usr/lib/bluetooth/bluetoothd does not have execution set
	sudo chmod +x "/usr/lib/bluetooth/bluetoothd"
}

clean_install()
{
	echo -e "\n==> Stopping sixad service"
	
	# stop  sixad init service if present
	if [[ -f "/etc/init.d/sixad" ]]; then
		sudo systemctl sixad stop
	fi
	sleep 1s
}

main()
{
  
  	clear
		
	# configure and start sixad daemon.
	echo -e "==> Configuring sixad...\n"
	sleep 2s
	
	sudo systemctl enable sixad
	sudo systemctl start sixad
  
  	echo -e "\c==> Configuring controller(s)...\n"
  	
  	echo -e "\n##############################################"
	echo -e "Please select the number of PS3 controllers"
	echo -e "##############################################\n"
	echo "(1)"
	echo "(2)"
	echo "(3)"
	echo "(4)"
	echo ""

	# the prompt sometimes likes to jump above sleep
	sleep 0.5s
	read -ep "Choice: " cont_num_choice

	case $cont_num_choice in
	
		1)
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s 
		;;
	
		2)
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s 
		
		# call pairing function to set current bluetooth MAC to Player 2
		n="2"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s 
		;;
	
		3)
	
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s 
	
		# call pairing function to set current bluetooth MAC to Player 2
		n="2"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
	
		# call pairing function to set current bluetooth MAC to Player 3
		n="3"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
		;;
	
		4)
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="2"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="3"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		echo -e "Pairing of Player $n controller complete\n"
		sleep 2s
		;;
	
	esac
	
	###########################################################
	# End controller pairing process
	###########################################################
	
	# start the service at boot time
	sixad --boot-yes
	
}
	
ps3_pair_blu()
{
	echo -e "\n#########################################"
	echo -e "Please plug in these items now:"
	echo -e "#########################################\n"
	echo -e "(1) The USB cable"
	echo -e "(2) PS3 controller $n"
	echo -e "(3) Bluetooth dongle"
	echo -e "\nPress [ENTER] to continue."
	
	read -n 1
        echo -e  "\nContinuing...\n"
	
	clear
	# Grab player 1 controller MAC Address of wired device
	echo -e "\n==> Setting up Playstation 3 Sixaxis (bluetooth) [Player $n]\n"
	sleep 2s
	
	# Pair controller with logging 
	# if hardcoded path is needed, sixpair should be in /usr/bin now
	sudo sixpair
	sleep 2s
	
	# Inform player 1 controller user to disconnect USB cord
	echo -e "\n##############################################################"
	echo -e "Connection Notice"
	echo -e "##############################################################"
	echo -e "\nPlease disconnect the USB cable and press the PS Button now. "
	echo -e "The appropriate LED for player $n should be lit. If it is not,"
	echo -e "please hold in the PS button to turn it off, then back on."
	echo -e "\nThere is no need to reboot to fully enable the controller(s)"
	
	echo -e "\nPress [ENTER] to continue."
	
	read -n 1
        echo -e  "\nContinuing...\n"
	
	clear
	echo -e "######################################################"
	echo -e "Notice for Steam users:"
	echo -e "######################################################\n"

	echo -e "Using the left stick and pressing the left and right "
	echo -e "stick navigate to the Settings Screen and edit the "
	echo -e "layout of the controller. By default, the left joystick"
	echo -e "should work and left-stick click will be assigned to"
	echo -e "OK/Confirm\n"

}

##################################################### 
# Install prereqs 
##################################################### 
clean_install
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
