#!/bin/bash

# -------------------------------------------------------------------------------
# Author:           Michael DeGuzis
# Git:		    https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	    brutal-doom.sh
# Script Ver:	    0.8.4
# Description:	    Installs the latest Brutal Doom under Linux / SteamOS
#
# Usage:	    ./brutal-doom.sh [install|uninstall]
#                   ./brutal-doom.sh -help
#
# Warning:	    You MUST have the Debian repos added properly for
#	            Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# get option
opt="$1"

# set scriptdir
scriptdir="$OLDPWD"

show_help()
{
  
  clear
  echo -e "Usage:\n"
  echo -e "./brutal-doom.sh [install|uninstall]"
  echo -e "./brutal-doom.sh -help\n"
  exit 1
}

gzdoom_set_vars()
{
	gzdoom_dir="/usr/games/gzdoom"
	gzdoom_launcher="/usr/bin/gzdoom-launcher"
	brutaldoom_launcher="/usr/bin/brutaldoom-launcher"
	
	wad_dir="$HOME/.config/gzdoom"
	wad_dir_steam="/home/steam/.config/gzdoom"
	gzdoom_config="$HOME/.config/gzdoom/zdoom.ini"
	antimicro_dir="/home/desktop/antimicro"
	gzdoom_desktop_file="/usr/share/applications/gzdoom-launch.desktop"
	bdoom_mod="/tmp/brutalv20.pk3"
	
	# Set default user options
	reponame="gzdoom"
	
	# tmp vars
	sourcelist_tmp="${reponame}.list"
	prefer_tmp="${reponame}"
	
	# target vars
	sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	prefer="/etc/apt/preferences.d/${reponame}"
}

gzdoom_add_repos()
{
  	clear
  	
  	echo -e "==> Importing drdteam GPG key\n"
  	
  	# Key Desc: drdteam Signing Key
	# Key ID: AF88540B
	# Full Key ID: 392203ABAF88540B
	gpg_key_check=$(gpg --list-keys AF88540B)
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "drdteam Signing Key [OK]"
		sleep 0.3s
	else
		echo -e "Debian Multimeda Signing Key [FAIL]. Adding now..."
		$scriptdir/utilities/gpg_import.sh AF88540B
	fi
  	
	echo -e "\n==> Adding GZDOOM repositories\n"
	sleep 1s
	
	# Check for existance of /etc/apt/preferences.d/{prefer} file
	if [[ -f ${prefer} ]]; then
		# backup preferences file
		echo -e "==> Backing up ${prefer} to ${prefer}.bak\n"
		sudo mv ${prefer} ${prefer}.bak
		sleep 1s
	fi

	# Create and add required text to preferences file
	# Verified policy with apt-cache policy
	cat <<-EOF > ${prefer_tmp}
	Package: *
	Pin: origin ""
	Pin-Priority:110
	EOF
	
	# move tmp var files into target locations
	sudo mv  ${prefer_tmp}  ${prefer}
	
	#####################################################
	# Check for lists in repos.d
	#####################################################
	
	# If it does not exist, create it
	
	if [[ -f ${sourcelist} ]]; then
        	# backup sources list file
        	echo -e "\n==> Backing up ${sourcelist} to ${sourcelist}.bak\n"
        	sudo mv ${sourcelist} ${sourcelist}.bak
        	sleep 1s
	fi

	#####################################################
	# Create and add required text to wheezy.list
	#####################################################

	# GZDOOM sources
	cat <<-EOF > ${sourcelist_tmp}
	# GZDOOM
	deb http://debian.drdteam.org/ stable multiverse
	EOF

	# move tmp var files into target locations
	sudo mv  ${sourcelist_tmp} ${sourcelist}

	# Update system
	echo -e "\n==> Updating index of packages, please wait\n"
	sleep 2s
	sudo apt-get update

}

cfg_gzdoom_controls()
{
	
	# Ask user if they want to use a joypad
	# TODO
	
	# YES:
	# sed -i 's|use_joystick=false|use_joystick=true|g' "$wad_dir/zdoom.ini"
	
	# NO:
	# sed -i 's|use_joystick=true|use_joystick=false|g' "$wad_dir/zdoom.ini"
	echo "" > /dev/null
	
}

gzdoom_main ()
{
  
	if [[ "$opt" == "-help" ]]; then
	
		show_help
	
	elif [[ "$opt" == "install" ]]; then
	
		clear
		
		#Inform user they will need WAD files before beginning
		
		# remove previous log"
		rm -f "$scriptdir/logs/gzdoom-install.log"
		
		# set scriptdir
		scriptdir="/home/desktop/SteamOS-Tools"
		
		############################################
		# Prerequisite packages
		############################################
		
		ep_install_antimicro
		gzdoom_set_vars
		gzdoom_add_repos
		
		echo -e "\n==> Installing prerequisite packages\n"
		sudo apt-get install unzip
		
		############################################
		# Backup original files
		############################################

		# backup original gzdoom desktop file
		# sudo cp "$gzdoom_exec" "$gzdoom_exec.bak"

		# backup wad dir if it exists
		if [[ -d "$wad_dir" ]]; then
			cp -r "$wad_dir" "$wad_dir.bak"
		fi

		############################################
		# Install GZDoom
		############################################
		
		echo -e "\n==> Installing GZDoom\n"
		sleep 2s
		
		sudo apt-get install gzdoom
		
		############################################
		# Configure
		############################################
		
		echo -e "\n==> Running post-configuration\n"
		sleep 2s
		
		# Warn user about WADS
		cat <<-EOF
		Please be aware, that in order to use Brutal Doom (aside from
		Installing GZDOOM here), you will need to acquire .wad files.
		These files you will have if you own Doom/Doom2/Doom Final.
		Rename all of these files including their .wad extensions to be 
		entirely lowercase. Remember, Linux filepaths are case sensitive.  
		
		Press [CTRL+C] to cancel Brutal Doom configuration, or enter the
		path to your WAD files now...
		
		EOF
		
		read -ep "WAD Directory: " user_wad_dir
		
		if [[ "$user_wad_dir" == "" ]]; then
			cat <<-EOF
			
			==Warning==
			No WAD DIR specified!
			You will need to manually copy your .wad
			files later to /usr/games/gzdoom! If you do NOT,
			GZDoom will fail to run!
			
			Press enter to continue...
			
			EOF
			read -r -n 1
			
		fi
		
		# Remove the previous config file / DIR (backed up previous)
		if [[ -d /home/desktop/.config/gzdoom ]]; then
			sudo rm -rf /home/desktop/.config/gzdoom
		fi
		
		# start gzdoom to /dev/null to generate blank zdoom.ini file
		# If zdoom.ini exists, gzdoom will launch, which we do not want
		gzdoom &> /dev/null
		
		
		##############################################
		# Download Brutal Doom
		##############################################
		
		echo -e "\n==> Downloading Brutal Doom mod, please wait\n"
		
		# See: http://www.moddb.com/mods/brutal-doom/downloads/brutal-doom-version-20
		# Need exact zip file name so curl can follow the redirect link
		
		cd /tmp
		curl -o brutalv20.zip -L http://www.moddb.com/downloads/mirror/85648/100/32232ab16e3826c34b034f637f0eb124
		unzip -o brutalv20.zip
		
		# ensure wad and pk3 files are not uppercase
		rename 's/\.WAD$/\.wad/' /tmp/*.WAD 2> /dev/null 2> /dev/null
		rename 's/\.PK3$/\.pk3/' /tmp/*.PK3 2>/dev/null 2> /dev/null
		
		echo -e "\n==> Copying available .wad and .pk3 files to $wad_dir\n"
		
		# find and copy over files
		# Filter out permission denied errors
		
		# TODO: come up with an automatic way to load latest brutal doom (i.e. v20) rather than
		# specify the exact file name in /usr/bin/brutaldoom-launcher
		find /tmp -name "*.wad" -exec cp -v {} $wad_dir \; 2>&1 | grep -v "Permission denied"
		find /tmp -name "*.pk3" -exec cp -v {} $wad_dir \; 2>&1 | grep -v "Permission denied"
		
		##############################################
		# Configure 
		##############################################
		
		# Default paths should be fine:
		
		# Path=~/.config/gzdoom
		# Path=/usr/local/share/
		# Path=$DOOMWADDI
		
		# fullscreen
		# sed -i 's|fullscreen=false|fullscreen=true|g' "$wad_dir/zdoom.ini"
		
		# Timidity++ sound
		# sed -i 's|snd_mididevice=-1|snd_mididevice=-2|g' "$wad_dir/zdoom.ini"
		
		# Instead of using sed swaps to congfigure, try dumping out config file for now
		# This will overwrite the generated config, so it will be backed up
		cp "$wad_dir/zdoom.ini" cp "$wad_dir/zdoom.ini.bak"
		cp "$scripdirext-game-installers/brutal-doom/zdoom.ini" "$wad_dir"
		
		# link configuration files to desktop user
		# possibly copy to the steam config directory for gzdoom later
		
		sudo rm -f "/home/steam/.config/gzdoom"
		sudo ln -s "$wad_dir" "/home/steam/.config/gzdoom"

		# copy our launcher into /usr/bin and mark exec
		sudo cp "$scriptdir/ext-game-installers/brutal-doom/gzdoom-launcher.sh" "$gzdoom_launcher"
		sudo cp "$scriptdir/ext-game-installers/brutal-doom/brutaldoom-launcher.sh" "$brutaldoom_launcher"
		sudo chmod +x "$gzdoom_launcher"
		sudo chmod +x "$brutaldoom_launcher"

		# copy our desktop files into /usr/share/applications
		sudo cp "$scriptdir/ext-game-installers/brutal-doom/gzdoom-launch.desktop" "/usr/share/applications"
		sudo cp "$scriptdir/ext-game-installers/brutal-doom/brutaldoom-launch.desktop" "/usr/share/applications"

		##############################################
		# Configure gamepad, if user wants it
		##############################################
		
		# Configure zdoom.ini or use antimicro?
		# # zdoom.ini has a parameter called 'use_joypad=false', but is wonky

		echo -e "\n==> Configuring Antimicro\n"

		if [[ -d "$antimicro_dir" ]]; then
			# DIR found
			echo -e "Antimicro DIR found. Skipping..."
		else
			# create dir
			mkdir -p "$antimicro_dir"
		fi
		
		# copy in default gamepad profiles
		sudo cp -r "$scriptdir/cfgs/gamepad/gzdoom/." "$antimicro_dir"

		echo -e "\n#############################################################"
		echo -e "Setting gamepad control for available gamepads"
		echo -e "#############################################################"

		# prompt user For controller type if they wish to enable gp mouse control
		echo -e "\nPlease choose your controller type for web app mouse control"
		echo "(1) Xbox 360 (wired)"
		echo "(2) Xbox 360 (wireless) - coming soon"
		echo "(3) PS3 Sixaxis (wired) - coming soon"
		echo "(4) PS3 Sixaxis (bluetooth) - coming soon"
		echo "(5) None (skip)"
		echo ""

		# the prompt sometimes likes to jump above sleep
		sleep 0.5s

		read -ep "Choice: " gp_choice

		case "$gp_choice" in

			1)
			am_cmd="antimicro --hidden --no-tray --profile $antimicro_dir/x360-wired-gzdoom.gamecontroller.amgp \&"
			;;

			2)
			
			;;
			 
			3)
			
			;;

			4)
			
			;;

			5)
			# do nothing
			;;
			 
			*)
			echo -e "\n==ERROR==\nInvalid Selection!"
			sleep 1s
			continue
			;;
		esac

		# perform swaps for mouse profiles
		sudo sed -i "s|#antimicro_tmp|$am_cmd|" "$gzdoom_launcher"

		##############################################
		# Cleanup
		##############################################

		# correct permissions
		sudo chown -R steam:steam "$wad_dir_steam"
		sudo chmod -R 755 "$wad_dir"
		sudo chmod -R 755 "$antimicro_dir"
		
		##############################################
		# Final notice for user
		##############################################
		
		cat <<-EOF

		==================================================================
		Results
		==================================================================
		Installation and configuration of GZDOOM for Brutal Doom complete.
		You can run BrutalDoom with the command 'gzdoom' in desktop mode,
		or add "GZDOOM" or "Brutal Doom" ass non-steam games in SteamOS BPM
		
		EOF
  
	elif [[ "$opt" == "uninstall" ]]; then
	
		#uninstall
		
		echo -e "\n==> Uninstalling GZDoom...\n"
		sleep 2s
		
		sudo apt-get remove gzdoom
		rm -rf "$wad_dir"
	
	else
	
		# if nothing specified, show help
		show_help
	
	# end install if/fi
	fi

}

#####################################################
# MAIN
#####################################################
# start script and log
gzdoom_main | tee "$scriptdir/logs/gzdoom-install.log"
