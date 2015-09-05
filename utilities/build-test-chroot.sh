#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.5.3
# Description:	Builds a Debian / SteamOS chroot for testing 
#		purposes. SteamOS targets allow only brewmaster release types.
#		based on repo.steamstatic.com
#               See: https://wiki.debian.org/chroot
#
# Usage:	sudo ./build-test-chroot.sh [type] [release]
# Options:	types: [debian|steamos] 
#		releases debian:  [wheezy|jessie]
#		releases steamos: [alchemist|alchemist_beta|brewmaster|brewmaster_beta]
#		
# Help:		sudo ./build-test-chroot.sh --help for help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# See Also:	https://wiki.debian.org/chroot
# -------------------------------------------------------------------------------

# set $USER since we run as root/sudo
# The reason for running sudo is do to the post install commands being inside the chroot
# Rather than run into issues adding user(s) to /etc/sudoers, we will run elevated.

export USER="$SUDO_USER"
#echo "user test: $USER"
#exit 1


# remove old custom files
rm -f "log.txt"

# set arguments / defaults
type="$1"
release="$2"
target="${type}-${release}"
stock_choice=""
full_target="${type}_${release}"

show_help()
{
	
	clear
	
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	
	Usage
	---------------------------------------------------------------
	sudo ./build-test-chroot.sh [type] [release]
	Types: [debian|steamos] 
	Releases (Debian):  [wheezy|jessie]
	Releases (SteamOS): [alchemist|alchemist_beta|brewmaster|brewmaster_beta]
	
	Plese note that the types wheezy and jessie belong to Debian,
	and that brewmaster belong to SteamOS.

	EOF
	exit
	
}

check_sources()
{
	
	# Debian sources are required to install xorriso for Stephenson's Rocket
	sources_check1=$(sudo find /etc/apt -type f -name "jessie*.list")
	sources_check2=$(sudo find /etc/apt -type f -name "wheezy*.list")
	
	if [[ "$sources_check1" == "" && "$sources_check2" == "" ]]; then
	
		echo -e "\n==WARNING==\nDebian sources are needed for building chroots, add now? (y/n)"
		read -erp "Choice: " sources_choice
	
		if [[ "$sources_choice" == "y" ]]; then
	
			../add-debian-repos.sh
			
		elif [[ "$sources_choice" == "n" ]]; then
		
			echo -e "Sources addition skipped"
		
		fi
		
	fi
	
	
}

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then

	clear
	
	cat <<-EOF
	==ERROR==
	Script must be run as root! Try:
	
	sudo $0 [type] [release]
	-OR-
	sudo $0 [type] [release]
	
	EOF
	
	exit 1
	
fi

funct_prereqs()
{
	
	echo -e "==> Installing prerequisite packages\n"
	sleep 1s
	
	# Install the required packages 
	apt-get install binutils debootstrap debian-archive-keyring -y
	
}

funct_set_target()
{
	
	# setup targets for appropriate details
	if [[ "$type" == "debian" ]]; then
	
		target_URL="http://http.debian.net/debian"
	
	elif [[ "$type" == "steamos" ]]; then
		
		target_URL="http://repo.steampowered.com/steamos"
		#target_URL="http://repo.steamstatic.com/steamos/dists/brewmaster/"
	
	elif [[ "$type" == "steamos-beta" ]]; then
	
		target_URL="http://repo.steampowered.com/steamos"
	
	elif [[ "$type" == "--help" ]]; then
		
		show_help
	
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
	# Key ID: 8ABDDD96
	# Full Key ID: 7DEEB7438ABDDD96
	gpg_key_check=$(gpg --list-keys 8ABDDD96)
	
	# check for key
	if [[ "$gpg_key_check" != "" ]]; then
		echo -e "\nDebian Archive Automatic Signing Key [OK]"
		sleep 1s
	else
		echo -e "\nDebian Archive Automatic Signing Key [FAIL]. Adding now..."
		./gpg_import.sh 7DEEB7438ABDDD96
	fi

}

funct_create_chroot()
{
	
	# create our chroot folder
	if [[ -d "/home/$USER/chroots/${target}" ]]; then
	
		# remove DIR
		rm -rf "/home/$USER/chroots/${target}"
		
	else
	
		mkdir -p "/home/$USER/chroots/${target}"
		
	fi
	
	# build the environment
	echo -e "\n==> Building chroot environment...\n"
	sleep 1s
	
	#debootstrap for SteamOS
	if [[ "$type" == "steamos" ]]; then
	
		# handle SteamOS
		/usr/sbin/debootstrap --keyring="/usr/share/keyrings/valve-archive-keyring.gpg" \
		--arch i386 ${release} /home/$USER/chroots/${target} ${target_URL}
		
	else
	
		# handle Debian instead
		/usr/sbin/debootstrap --arch i386 ${release} /home/$USER/chroots/${target} ${target_URL}
		
	fi
	
	# set script dir and enter
	script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
	cd $script_dir
	
	# copy over post install script for execution
	# cp -v scriptmodules/chroot-post-install.sh /home/$USER/chroots/${target}/tmp/
	echo -e "\n==> Copying post install script to tmp directory\n"
	cp -v "chroot-post-install.sh" "/home/$USER/chroots/${target}/tmp/"
	
	# mark executable
	chmod +x "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"

	# Modify type based on opts
	sed -i "s|"tmp_type"|${type}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# Change opt-in based on opts
	# sed -i "s|"tmp_beta"|${beta_flag}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# modify release_tmp for Debian Wheezy / Jessie in post-install script
	sed -i "s|"tmp_release"|${release}|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
	
	# create alias file that .bashrc automatically will source
	if [[ -f "/home/$USER/.bash_aliases" ]]; then
	
		# do nothing
		echo -e "\nBash alias file found, skipping creation."
	else
	
		echo -e "\nBash alias file not found, creating."
		# create file
		touch "/home/$USER/.bash_aliases"

	fi
	
	# create alias for easy use of command
	alias_check_steamos_brew=$(cat "/home/$USER/.bash_aliases" | grep chroot-steamos-brewmaster)
	alias_check_steamos_alch=$(cat "/home/$USER/.bash_aliases" | grep chroot-steamos-alchemist)
	alias_check_debian_wheezy=$(cat "/home/$USER/.bash_aliases" | grep chroot-debian-wheezy)
	alias_check_debian_jessie=$(cat "/home/$USER/.bash_aliases" | grep chroot-debian-jessie)
	
	if [[ "$alias_check_steamos_brew" == "" ]]; then
	
		cat <<-EOF >> "/home/$USER/.bash_aliases"
		
		# chroot alias for ${type} (${target})
		alias chroot-steamos-brewmaster='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
		
	elif [[ "$alias_check_steamos_alch" == "" ]]; then
	
		cat <<-EOF >> "/home/$USER/.bash_aliases"
		
		# chroot alias for ${type} (${target})
		alias chroot-steamos-alchemist='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
		
	elif [[ "$alias_check_debian_wheezy" == "" ]]; then
	
		cat <<-EOF >> "/home/$USER/.bash_aliases"
		
		# chroot alias for ${type} (${target})
		alias chroot-debian-wheezy='sudo /usr/sbin/chroot /home/$USER/chroots/${target}'
		EOF
		
	elif [[ "$alias_check_debian_jessie" == "" ]]; then
	
		cat <<-EOF >> "/home/$USER/.bash_aliases"
		
		# chroot alias for ${type} (${target})
		alias chroot-debian-jessie='sudo /usr/sbin/chroot /home/$USER/chroots/${target}'
		EOF
		
	fi
	
	# source bashrc to update.
	# bashrc should source /home/$USER/.bash_aliases
	
	# can't source form .bashrc, since they use ~ instead of $HOME
	# source from /home/$USER/.bash_aliases instead
	
	#source "/home/$USER/.bashrc"
	source "/home/$USER/.bash_aliases"
	
	# enter chroot to test
	cat <<-EOF
	
	------------------------------------------------------------
	Summary
	------------------------------------------------------------
	EOF

	echo -e "\nYou will now be placed into the chroot. Press [ENTER].
If you wish  to leave out any post operations and remain with a 'stock' chroot, type 'stock',
then [ENTER] instead. A stock chroot is only intended and suggested for the Debian chroot type."
	
	echo -e "You may use '/usr/sbin/chroot /home/desktop/chroots/${target}' to 
enter the chroot again. You can also use the newly created alias listed below\n"

	if [[ "$full_target" == "steamos_brewmaster" ]]; then
	
		echo -e "\tchroot-steamos-brewmaster\n"
	
	elif [[ "$full_target" == "debian_wheezy" ]]; then
	
		echo -e "\tchroot-debian-wheezyr\n"
		
	elif [[ "$full_target" == "steamos_brewmaster" ]]; then
	
		echo -e "\tchroot-steamos-wheezy\n"
		
	fi
	
	# Capture input
	read stock_choice
	
	if [[ "$stock_choice" == "" ]]; then
	
		# Captured carriage return / blank line only, continue on as normal
		# Modify target based on opts
		sed -i "s|"tmp_stock"|"no"|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
		#printf "zero length detected..."
		
	elif [[ "$stock_choice" == "stock" ]]; then
	
		# Modify target based on opts
		sed -i "s|"tmp_stock"|"yes"|g" "/home/$USER/chroots/${target}/tmp/chroot-post-install.sh"
		
	elif [[ "$stock_choice" != "stock" ]]; then
	
		# user entered something arbitrary, exit
		echo -e "\nSomething other than [blank]/[ENTER] or 'stock' was entered, exiting.\n"
		exit
	fi
	
	# "bind" /dev/pts
	mount --bind /dev/pts "/home/$USER/chroots/${target}/dev/pts"
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "/home/$USER/chroots/${target}" /bin/bash -c "/tmp/chroot-post-install.sh"
	
	# Unmount /dev/pts
	umount /home/$USER/chroots/${target}/dev/pts
	
	# correct owner on home directory files/folders due to usage of sudo
	chown -R $USER:$USER "/home/$USER"
}

main()
{
	clear
	check_sources
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

