#!/bin/bash

# -------------------------------------------------------------------------------
# Author:           Michael DeGuzis
# Git:		    https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	    brutal-doom.sh
# Script Ver:	    0.0.1
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
	wad_dir="~/.config/gzdoom/"
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
	gpg_key_check=$(gpg --list-keys 65558117)
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
        	echo -e "==> Backing up ${sourcelist} to ${sourcelist}.bak\n"
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
		
		gzdoom_set_vars
		gzdoom_add_repos
		
		echo -e "\n==> Installing prerequisite packages"
		sudo apt-get install unzip
		
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
		Pleas be aware, that in order to use Brutal Doom (aside from
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
		
		#######################
		# Download Brutal Doom
		#######################
		
		echo -e "\n==> Downloading Brutal Doom mod, please wait\n"
		
		# See: http://www.moddb.com/mods/brutal-doom/downloads/brutal-doom-version-20
		# Need exact zip file name so curl can follow the redirect link
		
		cd /tmp
		curl -o brutalv20.zip -L http://www.moddb.com/downloads/mirror/85648/100/32232ab16e3826c34b034f637f0eb124
		unzip -o brutalv20.zip
		
		# ensure wad and pk3 files are not uppercase
		rename 's/\.WAD$/\.wad/' /tmp/*.WAD
		rename 's/\.PK3$/\.pk3/' /tmp/*.PK3
		
		echo -e "\n==> Copying available .wad and .pk3 files to /usr/games/gzdoom\n"
		
		# find and copy over files
		find /tmp -name "*.WAD" -exec cp {} -t $wad_dir  \; #2> /dev/null
		find /tmp -name "*.pk3" -exec cp {} -t $wad_dir  \; #2> /dev/null

		##############################################
		# Configure ~/.config/gzdoom/zdoom.ini ?
		##############################################
		
		# Default paths should be fine:
		
		# Path=~/.config/gzdoom
		# Path=/usr/local/share/
		# Path=$DOOMWADDI
		
		cat <<-EOF
		==================================================================
		Results
		==================================================================
		Installation and configuration of GZDOOM for Brutal Doom complete.
		You can run BrutalDoom with the command 'gzdoom'.
		
		EOF
  
elif [[ "$opt" == "uninstall" ]]; then
	
	#uninstall
	
		echo -e "\n==> Uninstalling GZDoom...\n"
		sleep 2s
		
		sudo apt-get remove gzdoom
	
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
