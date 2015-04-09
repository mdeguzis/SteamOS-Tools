#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	0.5.9
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value.
#
# Loop description:
#		Checks all packages one by one if they are installed first.
#		if any given pkg is not, it then checks for a prefix !broke! 
#		in any dynamically called list (basic,extra,emulation, and so on)
#		Pkg names marked !broke! are skipped and the rest are 
#		attempted to be installed
#
# Usage:	./desktop-software.sh [option] [type]
# Options:	[install|uninstall|list|check] 
# Types:	[basic|extra|emulation|emulation-src|emulation-src-deps|<pkg_name>]
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

funct_set_vars()
{
	#################################
	# Set launch vars
	#################################
	options="$1"
	
	# loop argument 2 until no more is specfied
	while [ "$2" != "" ]; do
		# remove old custom file
		echo "removing old custom pkg file"
		sudo rm -f "cfgs/custom-pkg.txt"
		# set type var to arugment, append to custom list
		# for mutliple package specifications by user
		echo "adding custom pkgs"
		type="$2"
		echo "$type" >> "cfgs/custom-pkg.txt"
		# Shift all the parameters down by one
		shift
	done
}

apt_mode="install"
uninstall="no"


function getScriptAbsoluteDir() 
{
	
    # @description used to get the script path
    # @param $1 the script $0 parameter
    local script_invoke_path="$1"
    local cwd=$(pwd)

    # absolute path ? if so, the first character is a /
    if test "x${script_invoke_path:0:1}" = 'x/'
    then
	RESULT=$(dirname "$script_invoke_path")
    else
	RESULT=$(dirname "$cwd/$script_invoke_path")
    fi
}

function import() 
{
    
    # @description importer routine to get external functionality.
    # @description the first location searched is the script directory.
    # @description if not found, search the module in the paths contained in $SHELL_LIBRARY_PATH environment variable
    # @param $1 the .shinc file to import, without .shinc extension
    module=$1

    if [ -f $module.shinc ]; then
      source $module.shinc
      echo "Loaded module $(basename $module.shinc)"
      return
    fi

    if test "x$module" == "x"
    then
	echo "$script_name : Unable to import unspecified module. Dying."
        exit 1
    fi

	if test "x${script_absolute_dir:-notset}" == "xnotset"
    then
	echo "$script_name : Undefined script absolute dir. Did you remove getScriptAbsoluteDir? Dying."
        exit 1
    fi

	if test "x$script_absolute_dir" == "x"
    then
	echo "$script_name : empty script path. Dying."
        exit 1
    fi

    if test -e "$script_absolute_dir/$module.shinc"
    then
        # import from script directory
        . "$script_absolute_dir/$module.shinc"
        echo "Loaded module $script_absolute_dir/$module.shinc"
        return
    elif test "x${SHELL_LIBRARY_PATH:-notset}" != "xnotset"
    then
        # import from the shell script library path
        # save the separator and use the ':' instead
        local saved_IFS="$IFS"
        IFS=':'
        for path in $SHELL_LIBRARY_PATH
        do
          if test -e "$path/$module.shinc"
          then
                . "$path/$module.shinc"
                return
          fi
        done
        # restore the standard separator
        IFS="$saved_IFS"
    fi
    echo "$script_name : Unable to find module $module"
    exit 1
}


function loadConfig()
{
    # @description Routine for loading configuration files that contain key-value pairs in the format KEY="VALUE"
    # param $1 Path to the configuration file relate to this file.
    local configfile=$1
    if test -e "$script_absolute_dir/$configfile"
    then
        . "$script_absolute_dir/$configfile"
        echo "Loaded configuration file $script_absolute_dir/$configfile"
        return
    else
	echo "Unable to find configuration file $script_absolute_dir/$configfile"
        exit 1
    fi
}

function setDesktopEnvironment()
{

  arg_upper_case=$1
  arg_lower_case=`echo $1|tr '[:upper:]' '[:lower:]'`
  XDG_DIR="XDG_"$arg_upper_case"_DIR"
  xdg_dir="xdg_"$arg_lower_case"_dir"

  setDir=`cat $home/.config/user-dirs.dirs | grep $XDG_DIR| sed s/$XDG_DIR/$xdg_dir/|sed s/HOME/home/`
  target=`echo $setDir| cut -f 2 -d "="| sed s,'$home',$home,`

  checkValid=`echo $setDir|grep $xdg_dir=\"|grep home/`
 
  if [ -n "$checkValid" ]; then
    eval "$setDir"

  else

    echo "local desktop setting" $XDG_DIR "not found"
 
  fi
}

funct_source_modules()
{
	
script_invoke_path="$0"
script_name=$(basename "$0")
getScriptAbsoluteDir "$script_invoke_path"
script_absolute_dir=$RESULT

if [ "$script_invoke_path" == "/usr/bin/retrorig-es-setup" ]; then

	#install method via system folder
	
	scriptdir=/usr/share/RetroRig-ES
	
else

	#install method from local git clone
	
	scriptdir=`dirname "$script_absolute_dir"`
	
fi

}

show_help()
{
	
	clear
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	You have two options with this script:
	
	Basic
	---------------------------------------------------------------
	Standard Debian desktop application loadout.
	Based on: http://distrowatch.com/table.php?distribution=debian
	
	Extra
	---------------------------------------------------------------
	Extra software
	Based on feeback and personal preference.
	
	<pkg_name> 
	---------------------------------------------------------------
	Any package you wish to specify yourself. Alchemist repos will be
	used first, followed by Debian Wheezy.
	
	For a complete list, type:
	'./debian-software list [type]'
	Options: [install|uninstall|list|check] 
	Types: [basic|extra|emulation|emulation-src|emulation-src-deps|<pkg_name>]
	
	Install with:
	'./debian-software [option] [type]'

	Press enter to continue...
	EOF
	
	read -n 1
	printf "Continuing...\n"
	clear

}

# Show help if requested

if [[ "$1" == "--help" ]]; then
        show_help
	exit 0
fi

funct_pre_req_checks()
{
	
	# Adding repositories
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' python-software-properties | grep "install ok installed")
	
	if [ "" == "$PKG_OK" ]; then
		echo -e "python-software-properties not found. Setting up python-software-properties.\n"
		sleep 1s
		sudo apt-get install -t wheezy python-software-properties
	else
		echo "Checking for python-software-properties: [Ok]"
		sleep 0.2s
	fi
	
}

get_software_type()
{
	
	# set software type
        if [[ "$type" == "basic" ]]; then
                # add basic software to temp list
                software_list="cfgs/basic-software.txt"
        elif [[ "$type" == "extra" ]]; then
                # add full softare to temp list
                software_list="cfgs/extra-software.txt"
        elif [[ "$type" == "emulation" ]]; then
                # add emulation softare to temp list
                software_list="cfgs/emulation.txt"
        elif [[ "$type" == "emulation-src" ]]; then
                # add emulation softare to temp list
                software_list="cfgs/emulation-src.txt"
        elif [[ "$type" == "emulation-src-deps" ]]; then
                # add emulation softare to temp list
                software_list="cfgs/emulation-src-deps.txt"
        elif [[ "$type" == "$type" ]]; then
                # install based on $type string response
		software_list="cfgs/custom-pkg.txt"
        fi
        
}

add_repos()
{

	# set software type
        if [[ "$type" == "basic" ]]; then
                # non-required for now
                echo "" > /dev/null
        elif [[ "$type" == "extra" ]]; then
                # non-required for now
                echo "" > /dev/null
        elif [[ "$type" == "emulation" ]]; then
                # retroarch
                echo "" > /dev/null
        elif [[ "$type" == "emulation-src" ]]; then
                # retroarch-src
                echo "" > /dev/null
        elif [[ "$type" == "emulation-src-deps" ]]; then
                # retroarch-src-deps
                echo "" > /dev/null
        elif [[ "$type" == "$type" ]]; then
                # non-required for now
                echo "" > /dev/null
        fi
	
}

install_software()
{
	# For a list of Debian software pacakges, please see:
	# https://packages.debian.org/search?keywords=wheezy

	clear
	
	###########################################################
	# Pre-checks and setup
	###########################################################
	
	# Set mode and proceed based on main() choice
        if [[ "$options" == "uninstall" ]]; then
                apt_mode="remove"
	else
		apt_mode="install"
        fi
        
        # Update keys and system first
        echo -e "\nUpdating system, please wait...\n"
	sleep 1s
        sudo apt-key update
        sudo apt-get update

	# create alternate cache dir in /home/desktop due to the 
	# limited size of the default /var/cache/apt/archives size
	
	mkdir -p "/home/desktop/cache_temp"
	# create cache command
	cache_tmp=$(echo "-o dir::cache::archives="/home/desktop/cache_temp"")
	
	clear
	###########################################################
	# Installation routine (alchmist/main)
	###########################################################
	
	# Install from Alchemist first, Wheezy as backup, wheezy-backports 
	# as a last ditch effort
	
	# let user know checks in progress
	echo -e "\n\nValidating packages already installed...\n"
	sleep 1s
	
	for i in `cat $software_list`; do
	
		if [[ "$i" =~ "!broken!" ]]; then
			skipflag="yes"
			echo -e "skipping broken package: $i ..."
			sleep 1s
		else
	
			# check for packages already installed first
			PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
			# setup firstcheck var for first run through
			firstcheck="yes"
		
			if [ "" == "$PKG_OK" ]; then
			
				clear
				# try Alchemist first
				echo -e "\nPackage $i not found. Attempting installation...\n"
				sleep 1s
				echo -e "\nAttempting package installations from Alchemist...\n"
				sleep 1s
				sudo apt-get $cache_tmp $apt_mode $i
			 
				###########################################################
				# Installation routine (wheezy - 2nd stage)
				###########################################################
				
				# Packages that fail to install, use Wheezy repositories
				if [ $? == '0' ]; then
					echo -e "\nSuccessfully installed software from Alchemist repo! / Nothing to Install\n" 
				else
					clear
					echo -e "\nCould not install all packages from Alchemist repo, trying Wheezy...\n"
					sudo apt-get $cache_tmp -t wheezy $apt_mode $i
				fi
					
				###########################################################
				# Installation routine (wheezy-backports - 2nd stage)
				###########################################################
				
				# Packages that fail to install, use Wheezy-backports repository
				if [ $? == '0' ]; then
					echo -e "\nSuccessfully installed software from Wheezy repo! / Nothing to Install\n" 
				else
					clear
					echo -e "\nCould not install all packages from Wheezy repo, trying Wheezy-backports\n"
					sudo apt-get $cache_tmp -t wheezy-backports $apt_mode $i
					
					# clear the screen from the last install if it was. (looking into this)
					# a broken pkg
					if [[ "$skipflag" == "yes"  ]]; then
						clear
					fi
				fi
				
				###########################################################
				# Fail out if any pkg installs fail
				###########################################################
			
				if [ $? == '0' ]; then
					clear
					echo -e "\nCould not install all packages from Wheezy, trying Wheezy-backports...\n"
					sleep 2s
				fi
				
				# set firstcheck to "no" so "resume" below does not occur
				firstcheck="no"
	
			else
				# package was found
				# check if we resumed pkg checks if loop was restarted
				
				if [[ "$firstcheck" == "yes"  ]]; then
					
					echo -e "$i package status: [OK]"
					sleep 0.2s
				else
					clear
					echo -e "Restarting package checks...\n"
					sleep 3s
					echo -e "$i package status: [OK]"
					sleep 0.5s
				fi
			
			# end PKG OK test loop if/fi
			fi

		# end broken PKG test loop if/fi
		fi
		# reset skip flag
		skipflag="no"
		
	# end PKG OK test loop itself
	done
	
	if [ $? == '0' ]; then
		echo -e "\nAll packages (I hope!) installed successfully!\n"
	fi
	
	###########################################################
	# Cleanup
	###########################################################
	
	# Remove custom package list
	rm -f cfgs/custom-pkg.txt
	
	# If software type was for emulation, continue building
	# emulators from source (DISABLE FOR NOW)
	
	###########################################################
	# Kick off emulation install scripts (if specified)
	###########################################################
	
        if [[ "$type" == "emulation" ]]; then
                # call external build script
                # DISABLE FOR NOW
                # install_emus
                echo "" > /dev/null
        elif [[ "$type" == "emulation-src" ]]; then
                # call external build script
                clear
                echo -e "\nProceeding to install emulator pkgs from source..."
                sleep 2s
                efs_main
	fi
	
}

show_warning()
{

        clear
        printf "\nWarning: usage of this script is at your own risk!\n\n"
        printf "\nIn order to run this script, you MUST have had enabled the Debian\n"
        printf "repositories! If you wish to exit, please press CTRL+C now..."
        printf "\n\n type './debian-software --help' for assistance.\n"

        read -n 1
        printf "Continuing...\n"
        sleep 1s
}

main()
{
	clear
	
	# load script modules
	echo "#####################################################"
	echo "Loading script modules"
	echo "#####################################################"
	import "$scriptdir/scriptmodules/emu-from-source"

        # generate software listing based on type
        get_software_type

	if [[ "$type" == "basic" ]]; then

		if [[ "$options" == "uninstall" ]]; then
        		uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/basic-software.txt
                        clear
                        cat $software_list | less
			exit
		elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi

		show_warning
		install_software

	elif [[ "$type" == "extra" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/extra-software.txt
                        clear
			cat $software_list | less
			exit
                
                elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi
                
                show_warning
		install_software
                
        elif [[ "$type" == "emulation" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from cfgs/emulation.txt
                        clear
			cat $software_list | less
			exit
                
                elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi
                
	        show_warning
		install_software

        elif [[ "$type" == "emulation-src" ]]; then

		if [[ "$options" == "uninstall" ]]; then
	                uninstall="yes"
	
	        elif [[ "$options" == "list" ]]; then
	                # show listing from cfgs/emulation-src.txt
	                clear
			cat $software_list | less
			exit
	        
	        elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi
        
        	show_warning
		install_software
		
        elif [[ "$type" == "emulation-src-deps" ]]; then

		if [[ "$options" == "uninstall" ]]; then
	                uninstall="yes"
	
	        elif [[ "$options" == "list" ]]; then
	                # show listing from cfgs/emulation-src-deps.txt
	                clear
			cat $software_list | less
			exit
	        
	        elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi
        
        	show_warning
		install_software
		
        elif [[ "$type" == "$type" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # no list to show
                        clear
			echo -e "No listing for $type \n"
			exit
                
                elif [[ "$options" == "check" ]]; then
                        # check all packages on request
                        clear
			for i in `cat $software_list`; do
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "" == "$PKG_OK" ]; then
					# dpkg outputs it's own line that can't be supressed
					echo -e "Packge $i [Not Found]" > /dev/null
				else
					echo -e "Packge $i [OK]"
					sleep 0.2s
				fi
			done
			exit
		fi

		show_warning
		install_software
	fi
}

# handle prerequisite software
funct_set_vars
funct_source_modules
funct_pre_req_checks
add_repos

# Start main function
main
