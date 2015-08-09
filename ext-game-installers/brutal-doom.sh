#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      brutal-doom.sh
# Script Ver:	      0.0.1
# Description:	    Installs the latest Brutal Doom under Linux / SteamOS
#                   Based off of https://github.com/coelckers/gzdoom and
#                   http://zdoom.org/wiki/Compile_GZDoom_on_Linux
#                   Compile using CMake.
#
# Usage:	          ./brutal-doom.sh [install|uninstall]
#                   ./brutal-doom.sh -help
#
# Warning:	        You MUST have the Debian repos added properly for
#	                	Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# get option
opt="$1"

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
		echo -e "==> Adding GZDOOM repositories\n"
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
  
  # remove previous log"
  rm -f "$scriptdir/logs/gzdoom-install.log"
  
  # set scriptdir
  scriptdir="/home/desktop/SteamOS-Tools"
  
  ############################################
  # Prerequisite packages
  ############################################
  
  gzdoom_set_vars
  gzdoom_add_repos
  
  ############################################
  # vars (other)
  ############################################
  
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
  
  # TODO ?
  
elif [[ "$opt" == "uninstall" ]]; then
  
  #uninstall
  
  echo -e "\n==> Uninstalling GZDoom...\n"
  sleep 2s
  
  # Remove /usr/games/gzdoom directory and all its files:
  cd /usr/games && \
  sudo rm -rfv gzdoom
  # Remove gzdoom script:
  cd /usr/bin && \
  sudo rm -fv gzdoom
  
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
