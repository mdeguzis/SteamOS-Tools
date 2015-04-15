
# -----------------------------------------------------------------------
# Author: 		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/scripts
# Scipt Name:	  	extra-pkgs.
# Script Ver:	  	0.1.3
# Description:		Installs useful pacakges otherwise not found in
#			The Debian Wheezy repositories directly.
#	
# Usage:	      	./vaporos-pkgs.sh
# ------------------------------------------------------------------------

# remove fold files
sudo rm -f "log_temp.txt"

main()
{

	#####################################################
	# VaporOS bindings (controller shortcuts)
	#####################################################
	# FPS + more binds from VaporOS 2
	# For bindings, see: /etc/actkbd-steamos-controller.conf
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' vaporos-binds-xbox360 | grep "install ok installed")
	if [ "" == "$PKG_OK" ]; then
		echo -e "vaporos-binds-xbox360 not found. Setting up vaporos-binds-xbox360 now...\n"
		sleep 2s
		wget -P /tmp "https://github.com/sharkwouter/steamos-installer/blob/master/pool/main/v/vaporos-binds-xbox360/vaporos-binds-xbox360_1.0_all.deb"
		sudo dpkg -i "/tmp/vaporos-binds-xbox360_1.0_all.deb"
		#cleanup
		rm -f "/tmp/vaporos-binds-xbox360_1.0_all.deb"
		
		cd
		if [ $? == '0' ]; then
			echo "Successfully installed 'vaporos-binds-xbox360'"
			sleep 2s
		else
			echo "Could not install 'vaporos-binds-xbox360'. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Checking for 'vaporos-binds-xbox360 [OK]'."
		sleep 0.5s
	fi
	
	#####################################################
	# Firefox (imported 20150415)
	#####################################################
	# Imported from the Linux Mint LMDE 2 repository
	# Deb binary source: deb http://packages.linuxmint.com debian import
	
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' firefox | grep "install ok installed")
	if [ "" == "$PKG_OK" ]; then
		echo -e "\nFirefox not found. Setting up firefox now...\n"
		sleep 2s
		wget -P /tmp "http://www.libregeek.org/SteamOS-Extra/browsers/firefox_37.0~linuxmint1+betsy_amd64.deb"
		sudo dpkg -i "/tmp/firefox_37.0~linuxmint1+betsy_amd64.deb"
		# cleanup
		rm -f "/tmp/firefox_37.0~linuxmint1+betsy_amd64.deb"
		
		if [ $? == '0' ]; then
			echo "Successfully installed 'Firefox'"
			sleep 2s
		else
			echo "Could not install 'Firefox'. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Checking for 'Firefox [OK]'."
		sleep 0.5s
	fi

}

#####################################################
# MAIN
#####################################################
main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > log.txt

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' log.txt

# remove file not needed anymore
sudo rm -f "log_temp.txt"
