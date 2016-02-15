#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	2.0.3.1
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value. In any dynamically called 
#		list (basic,extra,emulation, and so on).Pkg names marked
#		!broke! are skipped and the rest are attempted to be installed
#
# Usage:	./desktop-software.sh [option] [type]
# optional:	Append "-test" to a package type called from ext. script
# Help:		./desktop-software.sh --help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

show_help()
{

	clear
	cat <<-EOF
	#####################################################
	Help File
	#####################################################
	Please see the desktop-software-readme.md file in the 
	wiki page on GitHub for full details.
	---------------------------------------------------------------
	Any package you wish to specify yourself. brewmaster repos will be
	used first, followed by Debian Jessie and the Libregeek repos.
	
	Please see the wiki entry for 'Desktop Software' for package
	listings and full instructions on what is available.
	
	Install software with:
	'sudo ./desktop-software [option] [type]'
	'sudo apt-get install [hosted_package]
	
	Large package lists:
	If you are pasting a build-depends post with symbols, please enclose the
	package list in quotes and it will be filterd appropriately.

	Press enter to continue...
	EOF
	
	read -r -n 1
	echo -e "\nContinuing...\n"
	clear

}

#################################
# Set launch vars
#################################
export options="$1"
export type="$2"
export build_opts="$3"
export build_opts_arg="$4"

#################################
# Initial traps for help/errors
#################################

if [[ "$options" == "" || "$options" == "--help" ]]; then

	# show help and exit
	show_help
	exit 1

fi

# Specify a final arg for any extra options to build in later
# The command being echo'd will contain the last arg used.
# See: http://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
export extra_opts=$(echo "${@: -1}")

# remove old custom files
rm -f "custom-pkg.txt"
rm -f "log.txt"

# loop argument 2 until no more is specfied
while [ "$2" != "" ]; do
	# set type var to arugment, append to custom list
	# for mutliple package specifications by user
	type_tmp="$2"
	echo "$type_tmp" >> "custom-pkg.txt"
	# Shift all the parameters down by one
	shift
done

# set custom flag for use later on if line count
# of testing custom pkg test errorssoftware-lists/custom-pkg.txt exceeds 1
if [ -f "custom-pkg.txt" ]; then
	LINECOUNT=$(wc -l "custom-pkg.txt" | cut -f1 -d' ')
else
	# do nothing
	echo "" > /dev/null 
fi

if [[ $LINECOUNT -gt 1 ]]; then

	# echo "Custom PKG set detected!"
	custom_pkg_set="yes"

fi

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

    if [ -f "$module.shinc" ]; then
      source "$module.shinc"
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

source_modules()
{

	script_invoke_path="$0"
	script_name=$(basename "$0")
	getScriptAbsoluteDir "$script_invoke_path"
	script_absolute_dir=$RESULT
	export scriptdir=`dirname "$script_absolute_dir"`

}

set_multiarch()
{

	echo -e "\n==> Checking for multi-arch support"
	sleep 1s

	# add 32 bit support
	multi_arch_status=$(dpkg --print-foreign-architectures)

	if [[ "$multi_arch_status" != "i386" ]]; then

		echo -e "Multi-arch support [Not Found]"
		# add 32 bit support
		if sudo dpkg --add-architecture i386; then

			echo -e "Multi-arch support [Added]"
			sleep 1s

		else

			echo -e "Multi-arch support [FAILED]"
			sleep 1s
		fi

	else

		echo -e "\nMulti-arch support [OK]"	

	fi

}

pre_req_checks()
{

	echo -e "\n==> Checking for prerequisite software...\n"
	sleep 2s

	# set pkg list
	PKGS="debian-keyring gdebi-core python-software-properties screen"

	# install packages
	main_install_eval_pkg

}


main_install_eval_pkg()
{

	#####################################################
	# Package eval routine
	#####################################################

	for PKG in ${PKGS}; 
	do
	
		# assess via dpkg OR traditional 'which'
		PKG_OK_DPKG=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
		PKG_OK_WHICH=$(which $PKG)
		
		if [[ "$PKG_OK_DPKG" == "" && "$PKG_OK_WHICH" == "" ]]; then
		
			echo -e "\n==INFO==\nInstalling package: ${PKG}\n"
			sleep 1s
			
			if sudo apt-get install ${PKG} -y --force-yes; then
			
				echo -e "\n${PKG} installed successfully\n"
				sleep 1s

			else
		
				echo -e "\n==ERROR==\nCould not install $PKG. Exiting..."
				echo -e "Did you remember to add the Debian sources?\n"
				sleep 3s
				exit 1
				
			fi

		else

			# package is already installed and OK
			echo "Checking for $PKG [OK]"
			sleep .1s

		fi
		
	done

}

function gpg_import()
{
	# When installing from jessie and jessie backports,
	# some keys do not load in automatically, import now
	# helper script accepts $1 as the key
	echo -e "\n==> Importing Debian and Librgeek GPG keys\n"
	sleep 1s


	# Key Desc: Libregeek Signing Key
	# Key ID: 34C589A7
	# Full Key ID: 8106E72834C589A7
	libregeek_keyring_test=$(dpkg-query -l libregeek-archive-keyring | grep "no packages")
	debian_eyring_test=$(dpkg-query -l debian-archive-keyring | grep "no packages")
	
	if [[ "${libregeek_keyring_test}" != "" || "${debiankeyring_test}" != "" ]]; then 
	
		wget http://packages.libregeek.org/libregeek-archive-keyring-latest.deb -q --show-progress -nc
		sudo dpkg -i libregeek-archive-keyring-latest.deb
		sudo apt-get install -y debian-archive-keyring

	fi

}

get_software_type()
{
	####################################################
	# Software packs
	####################################################

        if [[ "$type" == "basic" ]]; then
                # add basic software to temp list
                software_list="$scriptdir/cfgs/software-lists/basic-software.txt"
        elif [[ "$type" == "extra" ]]; then
                # add full softare to temp list
                software_list="$scriptdir/cfgs/software-lists/extra-software.txt"
        elif [[ "$type" == "emulators" ]]; then
                # add emulation softare to temp list
                software_list="$scriptdir/cfgs/software-lists/emulators.txt"
        elif [[ "$type" == "retroarch-src" ]]; then
                # add emulation softare to temp list
                software_list="$scriptdir/cfgs/software-lists/retroarch-src.txt"
        elif [[ "$type" == "gaming-tools" ]]; then
	        # add emulation softare to temp list
	        # remember to kick off script at the end of dep installs
	        software_list="$scriptdir/cfgs/software-lists/gaming-tools.txt"
        elif [[ "$type" == "games-pkg" ]]; then
                # add emulation softare to temp list
                # remember to kick off script at the end of dep installs
                software_list="$scriptdir/cfgs/software-lists/games-pkg.txt"
 
	####################################################
	# popular software / custom specification
	####################################################
	# This includes newly packages software from packages.libregeek.org

	elif [[ "$type" == "chrome" ]]; then
                # install chrome from helper script
		ep_install_chrome
                exit 1
        elif [[ "$type" == "gameplay-recording" ]]; then
                # install program from helper script
		ep_install_gameplay_recording
                exit 1
        elif [[ "$type" == "itchio" ]]; then
                # install itchio from helper script
		ep_install_itchio
                exit 1        
        elif [[ "$type" == "retroarch" ]]; then
                # add retroarch software Retroarch
                ep_install_retroarch
                exit 1
	elif [[ "$type" == "ut4" ]]; then
		# install ut4 from helper script
		egi_install_ut4
		exit 1
        elif [[ "$type" == "ut4-src" ]]; then
                # install UT4 from helper script
                software_list="$scriptdir/cfgs/software-lists/ue4.txt"
	elif [[ "$type" == "webapp" ]]; then
                # add web app via chrome from helper script
		add_web_app_chrome
                exit 1
        elif [[ "$type" == "$type" ]]; then
                # install based on $type string response
		software_list="custom-pkg.txt"
        fi
}

install_software()
{
	# For a list of Debian software pacakges, please see:
	# https://packages.debian.org/search?keywords=jessie

	###########################################################
	# Pre-checks and setup
	###########################################################

	# Set mode and proceed based on main() choice
        if [[ "$options" == "install" ]]; then

                export apt_mode="install"

	elif [[ "$options" == "uninstall" ]]; then

                export apt_mode="remove"

	elif [[ "$options" == "test" ]]; then

		export apt_mode="--dry-run install"

	elif [[ "$options" == "check" ]]; then

		echo "" > /dev/null

        fi

        # Update keys and system first, skip if removing software
        # or if we are just checking packages
 
	if [[ "$options" != "uninstall" && "$options" != "check" ]]; then
	        echo -e "\n==> Updating system, please wait...\n"
		sleep 1s
	        sudo apt-key update
	        sudo apt-get update
	fi

	# create alternate cache dir in /home/desktop due to the 
	# limited size of the default /var/cache/apt/archives size

	mkdir -p "/home/desktop/steamos-tools-aptcache"
	# create cache command
	cache_tmp=$(echo "-o dir::cache::archives="/home/desktop/steamos-tools-aptcache"")

	###########################################################
	# Installation routine (brewmaster/main)
	###########################################################

	# Install from brewmaster first, jessie as backup, jessie-backports 
	# as a last ditch effort

	# let user know checks in progress
	echo -e "\n==> Validating packages...\n"
	sleep 2s

	if [ -n "$software_list" ]; then
		for i in `cat $software_list`; do

			# set fail default
			pkg_fail="no"

			if [[ "$i" =~ "!broken!" ]]; then
				skipflag="yes"
				echo -e "skipping broken package: $i ..."
				sleep 0.3s
			else

				# check for packages already installed first
				# Force if statement to run if unininstalled is specified for exiting software
				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")

				# report package current status
				if [ "$PKG_OK" != "" ]; then

					echo -e "$i package status: [OK]"
					sleep .1s

				else
					echo -e "$i package status: [Not found]"
					sleep 1s

				fi

				# setup firstcheck var for first run through
				firstcheck="yes"

				# Assess pacakge requests
				if [ "$PKG_OK" == "" ] && [ "$apt_mode" == "install" ]; then

					echo -e "\n==> Attempting $i automatic package installation...\n"
					sleep 2s

					if sudo apt-get $cache_tmp $apt_mode $i -y; then
						
						echo -e "\n==INFO==\nSuccessfully installed package $i\n"
						
					else
						
						echo -e "\n==ERROR==\nFailed to install package $i"
						echo -e "Did you remember to add the Debian sources?\n"
						sleep 3s
						exit 1
						
					fi
						
				elif [ "$apt_mode" == "remove" ]; then
					
					echo -e "\n==> Removal requested for package: $i \n"
					
					if [ "$PKG_OK" == "" ]; then
						
						echo -e "==ERROR==\nPackage is not on this system! Removal skipped\n"
						sleep 2s
					fi
					
					if sudo apt-get $cache_tmp $apt_mode $i; then
					
						echo -e "\n==INFO==\nRemoval succeeded\n"
						
					else

						echo -e "\n==INFO==\nRemoval FAILED!\n"

					fi


				# end PKG OK/FAIL test loop if/fi
				fi

			# end broken PKG test loop if/fi
			fi

		# end PKG OK test loop itself
		done
	fi

	###########################################################
	# Cleanup
	###########################################################

	# Remove custom package list
	rm -f custom-pkg.txt

}

show_warning()
{
	# do a small check for existing jessie/jessie-backports lists
	echo ""
        sources_check_jessie=$(sudo find /etc/apt -type f -name "jessie*.list")
        sources_check_steamos_tools=$(sudo find /etc/apt -type f -name "steamos-tools.list")

        clear


        echo "##########################################################"
        echo "Warning: usage of this script is at your own risk!"
        echo "##########################################################"
        echo -e "\nIn order to install most software, you MUST have had"
        echo -e "enabled the Debian and Libregeek repositories! Otherwise,"
        echo -e "you may break the stability of your system packages! "

        if [[ "$sources_check_jessie" == "" || "$sources_check_steamos_tools" == "" ]]; then
                echo -e " \nThose sources do *NOT* appear to be added!"
        else
                echo -e "\nOn initial check, those sources appear to be added."
        fi

        echo -e "\nIf you wish to exit, please press CTRL+C now. Otherwise,"
        echo -e "press [ENTER] to continue."
        echo -e "\ntype './desktop-software --help' (without quotes) for help."
        echo -e "If you need to add the Debian repos, please add them now\n"
        echo -e "Please read the disclaimer.md now or in the main GitHub"
        echo -e "root folder!\n"

        echo -e "[c]ontinue, [a]dd Debian sources, [d]isclaimer [e]xit"

	# get user choice
	read -erp "Choice: " user_choice


	case "$user_choice" in
	        c|C)
		echo -e "\nContinuing..."
	        ;;

	        a|A)
		echo -e "\nProceeding to configure-repos.sh.sh"
		"$scriptdir/configure-repos.sh.sh"
	        ;;

  	        d|D)
		less disclaimer.md
		return
	        ;;

	        e|e)
		echo -e "\nExiting script...\n"
		exit 1
	        ;;


	        *)
		echo -e "\nInvalid Input, Exiting script.\n"
		exit
		;;
	esac

        sleep 2s

}

manual_software_check()
{

	echo -e "==> Validating packages already installed...\n"

	if [ -n "$software_list" ]; then
		for i in `cat $software_list`; do

			if [[ "$i" =~ "!broken!" ]]; then

				skipflag="yes"
				echo -e "skipping broken package: $i ..."
				sleep 0.3s

			else

				PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				if [ "$PKG_OK" == "" ]; then

					# dpkg outputs it's own line that can't be supressed
					echo -e "Package $i [Not Found]" > /dev/null
					sleep 1s

				else

					echo -e "Packge $i [OK]"
					sleep .1s

				fi
			fi

		done
	fi
	echo ""
	exit 1

}

main()
{
	clear

	# load script modules
	echo "#####################################################"
	echo "Loading script modules"
	echo "#####################################################"
	import "$scriptdir/scriptmodules/emulators"
	import "$scriptdir/scriptmodules/retroarch-post-cfgs"
	import "$scriptdir/scriptmodules/extra-pkgs"
	import "$scriptdir/scriptmodules/retroarch-from-src"
	import "$scriptdir/scriptmodules/ext-game-installers"
	import "$scriptdir/scriptmodules/web-apps"

        # generate software listing based on type or skip to auto script
        get_software_type
        
        #############################################
        # Main install functionality
        #############################################
        
	# Assess software types and fire of installation routines if need be.
	# The first section will be basic checks, then specific use cases will be
	# assessed.
	
	# Only specify lists in the first section if they require software lists
	# to be checked and installed as prerequisites
	
	if [[ "$type" == "basic" ||
	      "$type" == "extra" ||
	      "$type" == "emulation-src-deps" ||
	      "$type" == "retroarch-src" ||
	      "$type" == "$type" ]]; then

		if [[ "$options" == "uninstall" ]]; then
        		uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from $scriptdir/cfgs/software-lists
                        clear
                        less $software_list
                        exit 1

		elif [[ "$options" == "check" ]]; then

                        clear
                        # loop over packages and check
			manual_software_check
			exit 1
		fi

		# load functions necessary for software actions
		# GPG import should not be needed under brewmaster/Jessie

		gpg_import
		set_multiarch
		pre_req_checks

		# kick off install function
		install_software
	fi

        #############################################
        # Supplemental installs / modules
        #############################################

        # If an outside script needs called to install the software type,
        # do it below.

        if [[ "$type" == "emulators" ]]; then

		# kick off extra modules
		sleep 2s
		m_emulators_install_main

	elif [[ "$type" == "retroarch-src" ]]; then

                # call external build script for Retroarch
                clear
                sleep 2s
                rfs_retroarch_src_main

	elif [[ "$type" == "ue4-src" ]]; then

		# kick off ue4 script
		# m_install_ue4_src

		# Use binary built for Linux instead for brewmaster
		m_install_ue4

	elif [[ "$type" == "upnp-dlna" ]]; then

		# kick off helper script
		install_mobile_upnp_dlna
		
	fi

	# cleanup package leftovers
	echo -e "\n==> Cleaning up unused packages\n"
	sudo apt-get autoremove

	# Also, clear out our cache folder
	sudo apt-get -o dir::cache::archives="/home/desktop/steamos-tools-aptcache" clean

	echo ""
}

#####################################################
# handle prerequisite actions for script
#####################################################

source_modules
show_warning

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
rm -f "custom-pkg.txt"
rm -f "log_temp.txt"
