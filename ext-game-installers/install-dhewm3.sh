# TEMP WIP - DO NOT USE YET

# See: https://github.com/dhewm/dhewm3/wiki/FAQ

install_client()
{

	echo -e "\n==> Installing dhewm3 package"
	sleep 2s

	sources_check_jessie=$(sudo find /etc/apt -type f -name "jessie*.list")
        sources_check_steamos_tools=$(sudo find /etc/apt -type f -name "steamos-tools.list")

        if [[ "$sources_check_jessie" == "" || "$sources_check_steamos_tools" == "" ]]; then

                echo -e " \nDebian/LibreGeek sources do not appear to be installed. Please \
		run './configure-repos.sh' from the main SteamOS-Tools directory\n"
		sleep 2s
		exit 1

        fi

	sudo apt-get install -y --force-yes dhewm3

}

doom3_data_cdrom()
{

	#? CDROM (Does SteamOS automount in desktop mode / SSH?)

	# set disc var
	disc_num=1

	while [[ test "${disc_num}" -gt 0 ]];
	do

		echo -e "\nPlease insert disc ${disc_num} and press enter"
		read -erp FAKE_ENTER

		# mout disc and get files
		mkdir -p /tmp/doom3_data
		sudo mount -t auto /dev/sr0 /tmp/doom3_data
		find /tmp/doom3_data -iname "*.pk4" -exec sudo cp -v {} ${DOOM3_DATA} \;
		sudo umount /tmp/doom3_data

		# See if this is the last disc
		echo -e "Is this the last disc you have? [y/n]"
		sleep 0.2s
		read -erp "Choice: " disc_end

		if [[ "${disc_end}" == "n" ]]
			disc_num=$(($disc_num + 1))

		else
			disc_num=0
		fi

	done

	# ensure we have the patched files

	echo -e "Gather updated patch files\n"

	sleep 2s
	wget "http://libregeek.org/SteamOS-Extra/games/doom3/doom3-linux-1.3.1.1304.x86.run" -q -nq --show-progress
	chmod +x doom3-linux-1.3.1.1304.x86.run
	sh doom3-linux-1.3.1.1304.x86.run --tar xvf --wildcards base/pak* d3xp/p
	find . -iname "*.pk4" -exec sudo cp -v {} ${DOOM3_DATA} \;

	# cleanup
	rm -rf base d3xp doom3-linux*.run
	
}

doom3_data_steam()
{

	# get Doom3 files via steam (you must own the game!)
	echo -e "==> Acquiring files via Steam. You must own the game!"
	read -erp "    Steam username: " STEAM_LOGIN_NAME

	# Download
	./steamcmd.sh +@sSteamCmdForcePlatformType windows +login ${STEAM_LOGIN_NAME} \
	+force_install_dir ./doom3/ +app_update 9050 validate +quit

	# Extract .pk4 files
	find ./doom3/ -iname "*.pk4" -exec sudo cp -v {} ${DOOM3_DATA} \;

}

doom3_data_custom()
{

	# CUSTOM
	# ask for folder
	echo -e "\nPlease enter the path to the .pk4 files (must contain patched files!)"
	sleep 0.2s
	read -erp "Location: " custom_file_loc

	# copy files
	find ${custom_file_loc} -iname "*.pk4" -exec sudo cp -v {} ${DOOM3_DATA} \;

}

install_data_files()
{

	echo -e "\n==> Checking existance of data directory"

	# Set data dir
	DOOM3_DATA="/home/steam/doom3_data"
	DHEWM3_DIR="/home/steam/dhewm3"

	if [[ ! -d "${DOOM3_DATA}" ]]; then

		sudo mkdir -p "${DOOM3_DATA}"
		sudo chown -R steam:steam "${DOOM3_DATA}"

	fi

	# the prompt sometimes likes to jump above sleep
	cat<<- EOF
	==============================================
	Installing Data files for dhewm3
	==============================================
	Please choose a source:

	1) CD-ROM / DVD-ROM
	2) Steam game files (must be installed first)
	3) Custom location

	EOF

	sleep 0.5s

	read -ep "Choice: " install_choice

	case "$install_choice" in

		1)
		doom3_data_cdrom
		;;

		2)
		doom3_data_steam
		;;

		3)
		doom3_data_custom
		;;

		*)
		echo "Invalid selection!"
		sleep 1s
		continue
		;;

}

post_install()
{

	COPY LAUNCHER - TODO

	COPY DESKTOP FILE - TODO

	COPY ARTWORK - TODO

}

# main script
#install_client || exit 1
#install_data_files || exit 1
#post_install || exit 1
