#!/bin/bash

# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.1.3
# Description:	Builds a Debian / SteamOS chroot for testing 
#		purposes. SteamOS targets allow brewmaster/alchemist release types.
#               See: https://wiki.debian.org/chroot
#
# Usage:	sudo ./build-test-chroot.sh [OPTIONS]
# Options:	-type [debian|steamos] 
#		-release [wheezy|jessie|alchemist|brewmaster]
#
# Help:		sudo ./build-test-chroot.sh --help for help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# remove old custom files
rm -f "log.txt"

# set arguments / defaults
opt1="$1"
type="$2"
opt2="$3"
release="$4"
stock_choice=""

show_help()
{
	
	clear
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	
	Usage
	---------------------------------------------------------------
	sudo ./build-test-chroot.sh [type] [release]
	Types: [debian|steamos] 
	Releases: [wheezy|jessie|alchemist|brewmaster]
	
	Plese note that the types wheezy and jessie belong to Debian,
	and that alchemist and brewmaster belong to SteamOS.

	EOF
	exit
	
}

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then
	clear
	printf "\nScript must be run as root! Try:\n\n"
	printf "'sudo $0 install'\n\n"
	printf "OR\n"
	printf "\n'sudo $0 uninstall'\n\n"
	exit 1
fi

funct_prereqs()
{
	
	# Install the required packages 
	apt-get install binutils debootstrap debian-archive-keyring -y
	
}

funct_set_target()
{

	if [[ "$opt1" == "-type" ]]; then
	
	  if [[ "$type" == "debian" ]]; then
	  
	  	target="debian"
	  	release="jessie"
	  	target_URL="http://http.debian.net/debian"
	  	beta_flag="no"
	  	
	  elif [[ "$type" == "steamos" ]]; then
		
		target="steamos"
		release="brewmaster"
		target_URL="http://repo.steampowered.com/steamos"
		beta_flag="no"
	    
	  elif [[ "$type" == "steamos-beta" ]]; then
		
		target="steamos-beta"
		release="brewmaster"
		target_URL="http://repo.steampowered.com/steamos"
		beta_flag="yes"
	    
	  fi
	  
	elif [[ "$opt1" == "--help" ]]; then
		show_help
	fi

}

function gpg_import()
{
	# When installing from wheezy and wheezy backports,
	# some keys do not load in automatically, import now
	# helper script accepts $1 as the key
	
	echo -e "\n==> Importing Debian GPG keys"
	
	# Key Desc: Debian Archive Automatic Signing Key
	# Key ID: 8ABDDD96
	# Full Key ID: 7DEEB7438ABDDD96
	gpg_key_check=$(gpg --list-keys 8ABDDD96)
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "\nDebian Archive Automatic Signing Key [OK]\n"
		sleep 1s
	else
		echo -e "\nDebian Archive Automatic Signing Key [FAIL]. Adding now...\n"
		$scriptdir/utilities/gpg_import.sh 7DEEB7438ABDDD96
	fi

}

funct_create_chroot()
{

	if [[ "$target" == "steamos" ]]; then
		if [[ "$release" == "brewmaster" ]]; then
		# import GPG key
		gpg_import
		fi
	fi
	
	# create our chroot folder
	if [[ -d "/home/desktop/${target}-chroot" ]]; then
		# remove DIR
		rm -rf "/home/desktop/${target}-chroot"
	else
		mkdir -p "/home/desktop/${target}-chroot"
	fi
	
	# build the environment
	echo -e "\nBuilding chroot environment...\n"
	sleep 1s
	if [[ "$target" == "steamos" || "$target" == "steamos-beta" ]]; then
		/usr/sbin/debootstrap --keyring="/usr/share/keyrings/valve-archive-keyring.gpg" \
		--arch i386 ${release} /home/desktop/${target}-chroot ${target_URL}
	else
		/usr/sbin/debootstrap --arch i386 ${release} /home/desktop/${target}-chroot ${target_URL}
	fi
	
	script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
	cd $script_dir
	
	# copy over post install script for execution
	# cp -v scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	cp -v ../scriptmodules/chroot-post-install.sh /home/desktop/${target}-chroot/tmp/
	
	# mark executable
	chmod +x /home/desktop/${target}-chroot/tmp/chroot-post-install.sh

	# Modify target based on opts
	sed -i "s|"target_tmp"|${target}|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
	
	# Change opt-in based on opts
	sed -i "s|"beta_tmp"|${beta_flag}|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
	
	# enter chroot to test
	echo -e "\nYou will now be placed into the chroot. Press [ENTER]. If you wish to \
leave out any post operations and remain with a 'stock' chroot, type 'stock' and [ENTER] \
instead...\n"
	echo -e "You may use '/usr/sbin/chroot /home/desktop/${target}-chroot' to manually"
	echo -e "enter the chroot.\n"
	
	# Capture input
	read stock_choice
	
	if [[ "$stock_choice" == "" ]]; then
		# Captured carriage return / blank line only, continue on as normal
		# Modify target based on opts
		sed -i "s|"stock_tmp"|"no"|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
		#printf "zero length detected..."
		
	elif [[ "$stock_choice" == "stock" ]]; then
		# Modify target based on opts
		sed -i "s|"stock_tmp"|"yes"|g" "/home/desktop/${target}-chroot/tmp/chroot-post-install.sh"
		
	elif [[ "$stock_choice" != "stock" ]]; then
		# user entered something arbitrary, exit
		echo -e "\nSomething other than [blank]/[ENTER] or 'stock' was entered, exiting.\n"
		exit
	fi
	
	# "bind" /dev/pts
	mount --bind /dev/pts /home/desktop/${target}-chroot/dev/pts
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "/home/desktop/${target}-chroot" /bin/bash -c "/tmp/chroot-post-install.sh"
	
	# Unmount /dev/pts
	umount /home/desktop/${target}-chroot/dev/pts
}

main()
{
	clear
	funct_prereqs
	funct_set_target
	funct_create_chroot
	
}

#####################################################
# Main
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

