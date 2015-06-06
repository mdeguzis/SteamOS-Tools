#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	1.0.0.3
# Description:	Adds various desktop software to the system for a more
#		usable experience. Although this is not the main
#		intention of SteamOS, for some users, this will provide
#		some sort of additional value.in any dynamically called 
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

#################################
# Set launch vars
#################################
options="$1"
type="$2"
# Specify a final arg for any extra options to build in later
# The command being echo'd will contain the last arg used.
# See: http://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
extra_opts=$(echo "${@: -1}")

#############################################
# Test arguments (1st pass) here:
#############################################
#echo -e "\nOptions 1: $options"
#echo "Software type 1: $type"
#echo "Extra opts 1: $extra_opts"
#echo -e "Availble custom pkg list 1: \n"
#cat software-lists/custom-pkg.txt
#sleep 50s

# remove old custom files
rm -f "$scriptdir/cfgs/software-lists/custom-pkg.txt"
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

# Strip symbols from large pkg pastes from build-depends
sed -i "s|(>= [0-9].[0-9].[0-9])||g" "custom-pkg.txt"
sed -i "s|(<< [0-9].[0-9].[0-9])||g" "custom-pkg.txt"
sed -i "s|(>= [0-9].[0-9][0-9])||g" "custom-pkg.txt"
sed -i "s|(>= [0-9])||g" "custom-pkg.txt"
sed -i "s|(>= [0-9].[0-9][0-9])||g" "custom-pkg.txt"
sed -i "s|(>= [0-9]:[0-9].[0-9].[0-9].[0-9])||g" "custom-pkg.txt"
sed -i "s|(>= [0-9]:[0-9].[0-9][0-9])||g" "custom-pkg.txt"
sed -i "s|[ |]| |g" "custom-pkg.txt"
sed -i "s|  | |g" "custom-pkg.txt"

# set custom flag for use later on if line count
# of testing custom pkg test errorssoftware-lists/custom-pkg.txt exceeds 1
if [ -f "$scriptdir/software-lists/custom-pkg.txt" ]; then
	LINECOUNT=$(wc -l "software-lists/custom-pkg.txt" | cut -f1 -d' ')
else
	# do nothing
	echo "" > /dev/null 
fi

if [[ $LINECOUNT -gt 1 ]]; then
   echo "Custom PKG set detected!"
   custom_pkg_set="yes"
fi

#############################################
# Test arguments (2nd pass) here:
#############################################
#echo -e "\noptions 2: $options"
#echo "Software type 2: $type"
#echo "Extra opts 2: $extra_opts"
#echo -e "Availble custom pkg list 2: \n"
#cat software-lists/custom-pkg.txt
#sleep 10s

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
	scriptdir=`dirname "$script_absolute_dir"`

}

funct_set_multiarch()
{
	
	echo -e "\n==> Checking for multi-arch support\n"
	sleep 1s
	
	# add 32 bit support
	multi_arch_status=$(dpkg --print-foreign-architectures)
	
	if [[ "$multi_arch_status" != "i386" ]]; then
		
		echo -e "Multi-arch support [FAIL]"
		# add 32 bit support
		sudo dpkg --add-architecture i386
		
		if [[ $? == '0' ]]; then
				
			echo -e "Multi-arch support [Addition FAILED!]"
			sleep 1s
		else
			
			echo -e "Multi-arch support [Now added]"
			sleep 1s
		fi
	
	else
	
		echo -e "Multi-arch support [OK]"	
		
	fi
	
}

show_help()
{
	
	clear
	cat <<-EOF
	#####################################################
	Warning: usage of this script is at your own risk!
	#####################################################
	
	Please see the desktop-software-readme.md file in the 
	docs/ directory for full details.

	---------------------------------------------------------------
	Any package you wish to specify yourself. Alchemist repos will be
	used first, followed by Debian wheezy.
	
	For a complete list, type:
	'./desktop-software list [type]'
	
	
	Options: 	[install|uninstall|list|check|test] 
	Types: 		[basic|extra|emulation|emulation-src|emulation-src-deps]
	Types Cont.	[<pkg_name>|upnp-dlna|gaming-tools|games-pkg]
	Extra types: 	[firefox|kodi|lutris|plex|webapp]
	Functions: 	[x360-bindingsgameplay-recording]
	
	Install with:
	'sudo ./desktop-software [option] [type]'
	
	Large pacakge lists:
	If you are pasting a build-depends post with symbols, please enclose the
	package list in quotes and it will be filterd appropriately.

	Press enter to continue...
	EOF
	
	read -n 1
	echo -e "\nContinuing...\n"
	clear

}

# Show help if requested

if [[ "$1" == "--help" ]]; then
        show_help
	exit 0
fi

funct_pre_req_checks()
{
	
	echo -e "\n==> Checking for prerequisite software...\n"
	sleep 2s
	
	#################################
	# debian-keyring
	#################################
	# set vars
	PKG="debian-keyring"
	source_type=""
	
	main_install_eval_pkg
	
	#################################
	# gdebi
	#################################
	# set vars
	PKG="gdebi"
	source_type=""
	
	main_install_eval_pkg
	
}


main_install_eval_pkg()
{

	#####################################################
	# Package eval routine
	#####################################################
	
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
	if [ "" == "$PKG_OK" ]; then
		echo -e "\n==INFO==\n$PKG not found. Installing now...\n"
		sleep 2s
		sudo apt-get $cache_tmp ${source_type}install $PKG
		
		if [ $? == '0' ]; then
			echo "Successfully installed $PKG"
			sleep 2s
		else
			echo "Could not install $PKG. Exiting..."
			sleep 3s
			exit 1
		fi
	else
		echo "Checking for $PKG [OK]"

	fi

}

function gpg_import()
{
	# When installing from wheezy and wheezy backports,
	# some keys do not load in automatically, import now
	# helper script accepts $1 as the key
	echo -e "\n==> Importing Debian GPG keys"
	sleep 1s
	
	# Key Desc: Debian Archive Automatic Signing Key
	# Key ID: 2B90D010
	# Full Key ID: 7638D0442B90D010
	gpg_key_check=$(gpg --list-keys 2B90D010)
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "\nDebian Archive Automatic Signing Key [OK]"
		sleep 0.3s
	else
		echo -e "\nDebian Archive Automatic Signing Key [FAIL]. Adding now..."
		$scriptdir/utilities/gpg_import.sh 7638D0442B90D010
	fi
	
	# Key Desc: Debian Archive Automatic Signing Key
	# Key ID: 65558117
	# Full Key ID: 5C808C2B65558117
	gpg_key_check=$(gpg --list-keys 65558117)
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "Debian Multimeda Signing Key [OK]"
		sleep 0.3s
	else
		echo -e "Debian Multimeda Signing Key [FAIL]. Adding now..."
		$scriptdir/utilities/gpg_import.sh 5C808C2B65558117
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
        elif [[ "$type" == "emulation" ]]; then
                # add emulation softare to temp list
                software_list="$scriptdir/cfgs/software-lists/emulation.txt"
        elif [[ "$type" == "emulation-src" ]]; then
                # add emulation softare to temp list
                software_list="$scriptdir/cfgs/software-lists/emulation-src.txt"
        elif [[ "$type" == "emulation-src-deps" ]]; then
                # add emulation softare to temp list
                software_list="$scriptdir/cfgs/software-lists/emulation-src-deps.txt"
        elif [[ "$type" == "upnp-dlna" ]]; then
                # add emulation softare to temp list
                # remember to kick off script at the end of dep installs
                software_list="$scriptdir/cfgs/software-lists/upnp-dlna.txt"
        elif [[ "$type" == "gaming-tools" ]]; then
                # add emulation softare to temp list
                # remember to kick off script at the end of dep installs
                software_list="$scriptdir/cfgs/software-lists/gaming-tools.txt"
        elif [[ "$type" == "games-pkg" ]]; then
                # add emulation softare to temp list
                # remember to kick off script at the end of dep installs
                software_list="$scriptdir/cfgs/software-lists/games-pkg.txt"
        elif [[ "$type" == "pcsx2-testing" ]]; then
                # add emulation softare to temp list
                # remember to kick off script at the end of dep installs
                software_list="$scriptdir/cfgs/software-lists/pcsx2-src-deps.txt"
                m_install_pcsx2_src
                exit
            
	####################################################
	# popular software / custom specification
	####################################################

	elif [[ "$type" == "lutris" ]]; then
                # add web app via chrome from helper script
                ep_install_lutris
                exit
	elif [[ "$type" == "chrome" ]]; then
                # install plex from helper script
                ep_install_chrome
                exit
        elif [[ "$type" == "firefox" ]]; then
                # install plex from helper script
                ep_install_firefox
                exit
        elif [[ "$type" == "gameplay-recording" ]]; then
                # install plex from helper script
                ep_install_gameplay_recording
                exit
        elif [[ "$type" == "kodi" ]]; then
                # install plex from helper script
                ep_install_kodi
                exit
	elif [[ "$type" == "plex" ]]; then
                # install plex from helper script
                ep_install_plex
                exit
	elif [[ "$type" == "webapp" ]]; then
                # add web app via chrome from helper script
                ep_add_web_app_chrome
                exit
        elif [[ "$type" == "x360-bindings" ]]; then
                # install plex from helper script
                ep_install_x360_bindings
                exit
        elif [[ "$type" == "$type" ]]; then
                # install based on $type string response
		software_list="software-lists/custom-pkg.txt"
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
        elif [[ "$type" == "upnp-dlna" ]]; then
                # non-required for now
                echo "" > /dev/null
        elif [[ "$type" == "games" ]]; then
                # non-required for now
                echo "" > /dev/null
        fi
	
}

install_software()
{
	# For a list of Debian software pacakges, please see:
	# https://packages.debian.org/search?keywords=wheezy

	###########################################################
	# Pre-checks and setup
	###########################################################
	
	# Set mode and proceed based on main() choice
        if [[ "$options" == "install" ]]; then
                
                apt_mode="install"
                
	elif [[ "$options" == "uninstall" ]]; then
               
                apt_mode="remove"
                # only tee output
                
	elif [[ "$options" == "test" ]]; then
		
		apt_mode="--dry-run install"
		# grap Inst and Conf lines only
		
	elif [[ "$options" == "check" ]]; then
	
		# do nothing
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
	
	mkdir -p "/home/desktop/cache_temp"
	# create cache command
	cache_tmp=$(echo "-o dir::cache::archives="/home/desktop/cache_temp"")
	
	###########################################################
	# Installation routine (alchmist/main)
	###########################################################
	
	# Install from Alchemist first, wheezy as backup, wheezy-backports 
	# as a last ditch effort
	
	# let user know checks in progress
	echo -e "\n==> Validating packages...\n"
	sleep 2s
	
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
			
			# setup firstcheck var for first run through
			firstcheck="yes"
		
			if [ "" == "$PKG_OK" ] || [ "$apt_mode" == "remove" ]; then
			
				# try Alchemist first
				if [ "$apt_mode" != "remove" ]; then
					echo -e "\n==> Attempting $i automatic package installation / Alchemist repo...\n"
					sleep 1s
				else
					echo -e "\n==> Removal requested (from Alchemist) for package: $i \n"
					sleep 1s
				fi
				
				sudo apt-get $cache_tmp $apt_mode $i
				
				# REMOVED for now for further testing
				# return to loop if user hit "n" to removal instead of pushing onward
				#if [ $? == 1 ] && [ "$apt_mode" == "remove" ]; then
				#	# Return back to loop
				#	return
				#fi
			 
				###########################################################
				# Installation routine (wheezy - 2nd stage)
				###########################################################
				
				# Packages that fail to install, use wheezy repositories
				# The conf string is a part of a dry run result
				if [[ $? == '0' ]]; then
				
					if [ "$apt_mode" != "remove" ]; then
						echo -e "\n==> Successfully installed $i from Alchemist repo! / Nothing to Install"
						sleep 1s
					else
						echo -e "\n==> Removal succeeded for package: $i \n"
						sleep 1s
					fi
					
					# head back to for loop
					continue
				else
					
					if [ "$apt_mode" != "remove" ]; then
						echo -e "\n==> Could not install package $i from Alchemist repo, trying wheezy..."
						sleep 2s
					else
						echo -e "\n==> Removal requested (from wheezy) for package: $i \n"
						sleep 1s
					fi
					
					sudo apt-get $cache_tmp -t wheezy $apt_mode $i
					
				fi
					
				###########################################################
				# Installation routine (wheezy-backports - 2nd stage)
				###########################################################
				
				# Packages that fail to install, use wheezy-backports repository
				if [[ $? == '0' ]]; then
				
					if [ "$apt_mode" != "remove" ]; then
						echo -e "\n==> Successfully installed $i from wheezy repo! / Nothing to Install" 
						sleep 2s
					else
						echo -e "\n==> Removal succeeded for package: $i \n"
						sleep 1s
					fi
				
					# head back to for loop
					continue
				else
					
					if [ "$apt_mode" != "remove" ]; then
						echo -e "\n==> Could not install package $i from wheezy repo, trying wheezy-backports"
						sleep 2s
					else
						echo -e "\n==> Removal requested (from wheezy-backports) for package: $i"
						sleep 1s
					fi
					
					sudo apt-get $cache_tmp -t wheezy-backports $apt_mode $i
					
					# clear the screen from the last install if it was. (looking into this)
					# a broken pkg
					if [[ "$skipflag" == "yes"  ]]; then
						clear
					fi
				fi
				
				###########################################################
				# Fail out if any pkg installs fail (-z = zero length)
				###########################################################
			
				if [[ $? == '0' ]]; then
					
					# attempt to resolve missing
					sudo apt-get $cache_tmp $apt_mode -f
					
					echo -e "\n==> Could not install or remove ALL packages from wheezy.\n"
					echo -e "Please check log.txt in the directory you ran this from.\n"
					echo -e "Failure occurred on package: ${i}\n"
					pkg_fail="yes"
					exit
				fi
				
				# set firstcheck to "no" so "resume" below does not occur
				firstcheck="no"
	
			else
				# package was found
				# check if we resumed pkg checks if loop was restarted
				
				if [[ "$firstcheck" == "yes"  ]]; then
					
					echo -e "$i package status: [OK]"
					sleep 0.3s
				else
					
					echo -e "\n==> Restarting package checks...\n"
					sleep 3s
					echo -e "$i package status: [OK]"
					sleep 0.3s
				fi
			
			# end PKG OK test loop if/fi
			fi

		# end broken PKG test loop if/fi
		fi
		# reset skip flag
		skipflag="no"
		
	# end PKG OK test loop itself
	done
	
	###########################################################
	# Cleanup
	###########################################################
	
	# Remove custom package list
	rm -f software-lists/custom-pkg.txt
	
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
                echo -e "\n==> Proceeding to install emulator pkgs from source..."
                sleep 2s
                retroarch_src_main
                rpc_configure_retroarch
	fi
	
}

show_warning()
{
	# do a small check for existing wheezy/wheezy-backports lists
	echo ""
        sources_check=$(sudo find /etc/apt -type f -name "wheezy*.list")
        
        clear
        echo "##########################################################"
        echo "Warning: usage of this script is at your own risk!"
        echo "##########################################################"
        echo -e "\nIn order to install most software, you MUST have had"
        echo -e "enabled the Debian repositories! Otherwise, you may"
        echo -e -n "break the stability of your system packages! "
        
        if [[ "$sources_check" == "" ]]; then
                echo -e " Those \nsources do *NOT* appear to be added at first glance."
        else
                echo -e " On \ninitial check, those sources appear to be added."
        fi
                
        echo -e "\nIf you wish to exit, please press CTRL+C now. Otherwise,\npress [ENTER] to continue."
        echo -e "\ntype './desktop-software --help' (without quotes) for help.\n"
        echo -e "See log.txt in this direcotry after any attempt for details"
        echo -e "If you need to add the Debian repos, please use the"
        echo -e "desktop-software.sh script in the main repository folder..\n"
        
        echo -e "[c]ontinue, [a]dd Debian sources, [e]xit"

	# get user choice
	read -ep "Choice: " user_choice

	
	case "$user_choice" in
	        c|C)
		echo -e "\nContinuing..."
	        ;;
	        
	        a|A)
		echo -e "\nProceeding to add-debian-repos.sh"
		"$scriptdir/add-debian-repos.sh"
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

main()
{
	clear
	
	# load script modules
	echo "#####################################################"
	echo "Loading script modules"
	echo "#####################################################"
	import "$scriptdir/scriptmodules/retroarch-from-src"
	import "$scriptdir/scriptmodules/emulators-from-src"
	import "$scriptdir/scriptmodules/emulation"
	import "$scriptdir/scriptmodules/retroarch-post-cfgs"
	import "$scriptdir/scriptmodules/extra-pkgs"
	import "$scriptdir/scriptmodules/web-apps"

        # generate software listing based on type or skip to auto script
        get_software_type

	if [[ "$type" == "basic" ]]; then

		if [[ "$options" == "uninstall" ]]; then
        		uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from $scriptdir/cfgs/software-lists/basic-software.txt
                        clear
                        cat $software_list | less
			exit
		elif [[ "$options" == "check" ]]; then
                        
                        clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Package $i [Not Found]" > /dev/null
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			echo ""
			exit
		fi

		install_software

	elif [[ "$type" == "extra" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from $scriptdir/cfgs/software-lists/extra-software.txt
                        clear
			cat $software_list | less
			exit
                
                elif [[ "$options" == "check" ]]; then
                        
                        clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Packge $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			echo ""
			exit
		fi
                
		install_software
                
        elif [[ "$type" == "emulation" ]]; then

		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # show listing from $scriptdir/cfgs/software-lists/emulation.txt
                        clear
			cat $software_list | less
			exit
                
                elif [[ "$options" == "check" ]]; then
                        
                        clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Packge $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			
			# We also want to loop through the module, checks will output fine 
			m_emulation_install_main
			exit
			
		fi
                
		install_software
		# kick off extra modules for buld debs
		echo -e "\n==> Proceeding to supplemental emulation package routine\n"
		sleep 2s
		m_emulation_install_main

        elif [[ "$type" == "emulation-src" ]]; then

		if [[ "$options" == "uninstall" ]]; then
	                uninstall="yes"
	
	        elif [[ "$options" == "list" ]]; then
	                # show listing from $scriptdir/cfgs/software-lists/emulation-src.txt
	                clear
	                echo $type
	                echo $options
			cat $software_list | less
			exit
	        
	        elif [[ "$options" == "check" ]]; then
	        	
	        	clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Packge $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			echo ""
			exit
		fi
        
		install_software
		
        elif [[ "$type" == "emulation-src-deps" ]]; then

		if [[ "$options" == "uninstall" ]]; then
	                uninstall="yes"
	
	        elif [[ "$options" == "list" ]]; then
	                # show listing from $scriptdir/cfgs/software-lists/emulation-src-deps.txt
	                clear
			cat $software_list | less
			exit
	        
	        elif [[ "$options" == "check" ]]; then

                        clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Packge $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			echo ""
			exit
			
		fi
        
		install_software
		
	elif [[ "$type" == "upnp-dlna" ]]; then

		if [[ "$options" == "uninstall" ]]; then
	                uninstall="yes"
	
	        elif [[ "$options" == "list" ]]; then
	                # show listing from $scriptdir/cfgs/software-lists/upnp-dlna.txt
	                clear
			cat $software_list | less
			exit
	        
	        elif [[ "$options" == "check" ]]; then

                        clear
                        # loop over packages and check
			echo -e "==> Validating packages already installed...\n"
			
			for i in `cat $software_list`; do
			
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
				
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Packge $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Packge $i [OK]"
						sleep 0.3s
					fi
				fi
			done
			echo ""
			exit
			
		fi
        
		install_software
		
		# kick off helper script
		install_mobile_upnp_dlna
		
        elif [[ "$type" == "$type" ]]; then
        
		if [[ "$options" == "uninstall" ]]; then
                        uninstall="yes"

                elif [[ "$options" == "list" ]]; then
                        # no list to show
                        clear
			echo -e "No listing for $type \n"
			exit
                
                elif [[ "$options" == "check" ]]; then
                	
                	clear
			# loop over packages and check
			echo -e "==> Validating packages already installed...\n"
	
			for i in `cat $software_list`; do
				if [[ "$i" =~ "!broken!" ]]; then
					skipflag="yes"
					echo -e "skipping broken package: $i ..."
					sleep 0.3s
				else
					PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i | grep "install ok installed")
					
					if [ "" == "$PKG_OK" ]; then
						# dpkg outputs it's own line that can't be supressed
						echo -e "Package $i [Not Found]"
						sleep 0.3s
					else
						echo -e "Package $i [OK]"
						sleep 0.3s
						
					fi
				fi

			done
			echo ""
			exit
		fi
		install_software
	fi
	
	
	# cleanup package leftovers
	echo -e "\n==> Cleaning up unused packages\n"
	sudo apt-get autoremove
	echo ""
}

#####################################################
# handle prerequisite software
#####################################################

funct_source_modules
show_warning
gpg_import
funct_set_multiarch
funct_pre_req_checks
add_repos

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
rm -f "software-lists/custom-pkg.txt"
rm -f "log_temp.txt"
