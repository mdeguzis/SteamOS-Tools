#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	0.3.7
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value.
#
# Usage:	./desktop-software.sh [option] [type]
# Options:	[install|uninstall|list] 
# Types:	[basic|extra|emulation|emulation-src|emulation-src-deps|<pkg_name>]
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# -------------------------------------------------------------------------------

#################################
# Set launch vars
#################################

options="$1"

# loop argument 2 until no more is specfied
while [ "$2" != "" ]; do
    # set type var to arugment, append to custom list
    # for mutliple package specifications by user
    type="$2"
    echo "$type" >> "cfgs/custom-pkg.txt"
    # Shift all the parameters down by one
    shift
done


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
	Options: [install|uninstall|list] 
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
	
	# Inform user of preliminary action
	clear
	echo -e "\n\nAttempting package installations from Alchemist...\n"
	sleep 2s
	
	# Install from Alchemist first, Wheezy as backup
	for i in `cat $software_list`; do
		# skip any pkgs marked broken (testing branch only)
		# Install all others
		if [ $i != '*broken *' ]; then
			sudo apt-get $cache_tmp $apt_mode $i 2> /dev/null
		fi
	done 
	
	# Packages that fail to install, use Wheezy repositories
	if [ $? == '0' ]; then
		echo -e "\nSuccessfully installed software from Alchemist repo! / Nothing to Install\n" 
	else
		clear
		echo -e "\nCould not install all packages from Alchemist repo, trying Wheezy...\n"
		sleep 2s
		sudo apt-get $cache_tmp -t wheezy $apt_mode `cat $software_list`
		
		if [ $? == '0' ]; then
			echo -e "\nSuccessfully installed software from Wheezy! / Nothing to Install\n" 
		else
			clear
			echo -e "\nCould not install all packages from Wheezy, trying Wheezy-backports...\n"
			sleep 2s
			sudo apt-get $cache_tmp -t wheezy-backports $apt_mode `cat $software_list`
		fi
		
		if [ $? == '0' ]; then
			echo -e "\nSuccessfully installed software from Wheezy-backports! / Nothing to Install\n" 
			
		else
			clear
			echo -e "\nCould not install all packages. Please check errors displayed"
			echo -e "\nor run 'sudo ./install-debian-software [option] [type] &> log.txt\n"
			sleep 3s
			# halt script
			exit
		fi
	fi
	
	# Remove custom package list
	rm -f cfgs/custom-pkg.txt
	
	# If software type was for emulation, continue building
	# emulators from source (DISABLE FOR NOW)
	
        if [[ "$type" == "emulation" ]]; then
                # call external build script
                # DISABLE FOR NOW
                # install_emus
                echo "" > /dev/null
        elif [[ "$type" == "emulation-src" ]]; then
                # call external build script
                clear
                echo -e "Proceeding to install emulator pkgs from source..."
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
                fi

		show_warning
		install_software
	fi
}

# handle prerequisite software
funct_source_modules
funct_pre_req_checks
add_repos

# Start main function
main
