#!/bin/bash

install_prereqs()
{
	
	# Adding repositories
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' dialog | grep "install ok installed")
	
	if [ "" == "$PKG_OK" ]; then
		echo -e "dialog not found. Installing now...\n"
		sleep 1s
		sudo apt-get install -t wheezy dialog
	else
		echo "Checking for dialog: [Ok]"
		sleep 0.2s
	fi
	
}

main()
{
  
	# Download qtsixad and sixad
	# These are Debian rebuilt packages from the ppa:falk-t-j/qtsixa PPA
	wget -P /tmp "http://www.libregeek.org/SteamOS-Extra/utilities/qtsixa_1.5.1+git20140130-SteamOS_amd64.deb"
	wget -P /tmp "http://www.libregeek.org/SteamOS-Extra/utilities/sixad_1.5.1+git20130130-SteamOS_amd64.deb"
	
	# Install and start sixad daemon.
	sudo dpkg -i "/tmp/qtsixa_1.5.1+git20140130-SteamOS_amd64.deb"
	sudo dpkg -i "/tmp/sixad_1.5.1+git20130130-SteamOS_amd64.deb"
	
	sudo update-rc.d sixad defaults
	sudo /etc/init.d/sixad enable
	sudo /etc/init.d/sixad start
  
	cmd=(dialog --backtitle "LibreGeek.org RetroRig Installer" \
		    --menu "Please select the number of PS3 controllers" 16 47 16)
	options=(1 "1"
	 	 2 "2"
	 	 3 "3"
	 	 4 "4")

	#make menu choice
	selection=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	#functions
	
	for choice in $selection
	do
		case $choice in
	
		1)
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 1 Controller complete" 5 43 
		;;
	
		2)
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 1 controller complete" 5 43 
		
		# call pairing function to set current bluetooth MAC to Player 2
		n="2"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 2 controller complete" 5 43 
		;;
	
		3)
	
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 1 controller complete" 5 43 
	
		# call pairing function to set current bluetooth MAC to Player 2
		n="2"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 2 controller complete" 5 43 
	
		# call pairing function to set current bluetooth MAC to Player 3
		n="3"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 3 controller complete" 5 43 
		;;
	
		4)
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 1 controller complete" 5 43 
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="2"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 2 controller complete" 5 43 
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="3"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 3 controller complete" 5 43 
		
		# call pairing function to set current bluetooth MAC to Player 1
		n="1"
		ps3_pair_blu
		dialog --msgbox "Pairing of Player 4 controller complete" 5 43 
	
		esac
		
	done
	
	###########################################################
	# End controller pairing process
	###########################################################
	
	# start the service at boot time
	sixad --boot-yes
	
}
	
ps3_pair_blu()
{
	
	dialog --msgbox "Please plug in these items now:\n\n1)The USB cable\n2)PS3 controller $n \n \
	3)Bluetooth dongle\n\nAdditional controllers can be added in the settings menu"  12 40
	
	# Grab player 1 controller MAC Address of wired device
	echo -e "\nSetting up Playstation 3 Sixaxis (bluetooth) [Player $n]"\n"
	sleep 2s
	
	# Pair controller with logging
	sudo sixpair
	sleep 2s
	
	# Inform player 1 controller user to disconnect USB cord
	dialog --msgbox "Please disconnect the USB cable and press the PS Button now. The appropriate \
	LED for player $n should be lit. If it is not, please hold in the PS button to turn it off, then \
	back on.\n\nThere is no need to reboot to fully enable the controller\(s\)" 12 60
	
	echo -e "\nUsing the left stick and pressing the left and right stick navigate to the Settings Screen 
	and edit the layout of the controller."

}

##################################################### 
# Install prereqs 
##################################################### 
install_prereqs

##################################################### 
# MAIN 
##################################################### 
main | tee log_temp.txt 

##################################################### 
# cleanup 
##################################################### 

 922
# convert log file to Unix compatible ASCII 
strings log_temp.txt > log.txt 

# strings does catch all characters that I could  
# work with, final cleanup 
sed -i 's|\[J||g' log.txt 

# remove file not needed anymore 
rm -f "log_temp.txt" 
