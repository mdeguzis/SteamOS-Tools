#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-test-chroot.sh
# Script Ver:	0.8.2
# Description:	Builds a Debian / SteamOS chroot for testing 
#		purposes. based on repo.steamstatic.com
#               See: https://wiki.debian.org/chroot
#
# Usage:	sudo ./build-test-chroot.sh [type] [release] [arch]
# Options:	types: [debian|steamos|ubuntu] 
#		releases debian:  [wheezy|jessie]
#		releases steamos: [alchemist|alchemist-beta|brewmaster|brewmaster-beta]
#		releases ubuntu:  [trusty|vivid]
#		
# Help:		sudo ./build-test-chroot.sh --help for help
#
# Warning:	You MUST have the Debian repos added properly for
#		Installation of the pre-requisite packages.
#
# See Also:	https://wiki.debian.org/chroot
# -------------------------------------------------------------------------------

#####################################################
# Vars
#####################################################

# set $user since we run as root/sudo
# The reason for running sudo is do to the post install commands being inside the chroot
# Rather than run into issues adding user(s) to /etc/sudoers, we will run elevated.
export user="$SUDO_USER"

# remove old custom files
rm -f "log.txt"

# set arguments / defaults
type="$1"
release="$2"
arch="$3"
target="${type}-${release}-${arch}"
stock_choice=""
alias_file="/home/$user/.bash_aliases"
chroot_dir="/home/$user/chroots/${target}"

#####################################################
# Pre-flight checks
#####################################################

# Warn user script must be run as root
if [ "$(id -u)" -ne 0 ]; then

	clear
	
	cat <<-EOF
	==ERROR==
	Script must be run as root! Try:
	
	sudo $0 [type] [release]
	
	EOF
	
	exit 1
	
fi

# shutdown script if type or release is blank or note supported
if [[ "$type" == "" || "$release" == "" ]]; then

	clear
	echo -e "==ERROR==\nType or release not specified! Dying...\n"
	exit 1
	
elif [[ "$type" != "steamos" && 
	"$type" != "debian" &&
	"$type" != "ubuntu" ]]; then
	
	echo -e "\nType detected was $type. Distribution target not supported. Dying."
	sleep 3s
	exit 1
	
fi

show_help()
{
	
	clear
	
	cat <<-EOF
	Warning: usage of this script is at your own risk!
	
	Usage
	---------------------------------------------------------------
	sudo ./build-test-chroot.sh [type] [release] [arch]
	Types: [debian|steamos|ubuntu] 
	Releases (Debian):  [wheezy|jessie]
	Releases (SteamOS): [alchemist|alchemist-beta|brewmaster|brewmaster-beta]
	arch: [i386|amd64]
	
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
	
			../../add-debian-repos.sh
			
		elif [[ "$sources_choice" == "n" ]]; then
		
			echo -e "Sources addition skipped"
		
		fi
		
	fi
	
}


funct_prereqs()
{
	
	echo -e "==> Installing prerequisite packages\n"
	sleep 1s
	
	# Install the required packages 
	apt-get install -y binutils debootstrap debian-archive-keyring ubuntu-archive-keyring
	
	# update for keyrings
	
	echo -e "\n==> Updating system for newly added keyrings\n"
	sleep 2s
	sudo apt-key update
	sudo apt-get update
	
}

funct_set_target()
{
	
	# Setup targets for appropriate details
	# Note: in the future, possibly allow users to specify localized mirrors
	
	if [[ "$type" == "debian" ]]; then
	
		target_URL="http://http.debian.net/debian"
	
	elif [[ "$type" == "steamos" ]]; then
		
		target_URL="http://repo.steampowered.com/steamos"
	
	elif [[ "$type" == "steamos-beta" ]]; then
	
		target_URL="http://repo.steampowered.com/steamos"
		
	elif [[ "$type" == "ubuntu" ]]; then

		target_URL="http://mirrors.mit.edu/ubuntu/"
	
	elif [[ "$type" == "--help" ]]; then
		
		show_help
	
	fi

}

funct_set_arch()
{
	# fallback to 64bit if no arch is specified
	if [[ "$arch" == "" ]]; then
	
		arch="amd64"
	
	fi
}

funct_create_chroot()
{
	#echo -e "\n==> Importing GPG keys\n"
	#sleep 1s
	
	# create our chroot folder
	if [[ -d "${chroot_dir}" ]]; then
	
		# remove DIR
		rm -rf "${chroot_dir}"
		
	else
	
		mkdir -p "${chroot_dir}"
		
	fi
	
	# build the environment
	echo -e "\n==> Building chroot environment...\n"
	sleep 1s
	
	# debootstrap
	if [[ "$type" == "steamos" || "$type" == "steamos-beta" ]]; then
	
		# handle SteamOS
		/usr/sbin/debootstrap --keyring="/usr/share/keyrings/valve-archive-keyring.gpg" \
		--arch ${arch} ${release} ${chroot_dir} ${target_URL} 
		
	elif [[ "$type" == "debian" ]]; then
	
		# handle Debian
		/usr/sbin/debootstrap --components=main,contrib,non-free --arch ${arch} ${release} \
		${chroot_dir} ${target_URL}
		
	elif [[ "$type" == "ubuntu" ]]; then
	
		# handle Ubuntu
		/usr/sbin/debootstrap --components=main,multiverse,restricted,universe --arch ${arch} ${release} \
		${chroot_dir} ${target_URL}
		
	fi
	
	echo -e "\n==> Configuring"
	sleep 1s
	
	# add to fstab
	fstab_check=$(cat /etc/fstab | grep ${target})
	if [[ "$fstab_check" == "" ]]; then
	
		# Mount proc and dev filesystem (add to **host** fstab)
		sudo su -c "echo '#chroot ${target}' >> /etc/fstab"
		sudo su -c "echo '/dev/pts ${chroot_dir}/dev/pts none bind 0 4' >> /etc/fstab"
		sudo su -c "echo 'proc ${chroot_dir}/proc proc defaults 0 4' >> /etc/fstab"
		sudo su -c "echo 'sysfs ${chroot_dir}/sys sysfs defaults 0 4' >> /etc/fstab"
		
	fi
	
	# set script dir and enter
	script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
	cd $script_dir
	
	# create alias file that .bashrc automatically will source
	if [[ -f "${alias_file}" ]]; then
	
		# do nothing
		echo -e "\nBash alias file found, skipping creation."
	else
	
		echo -e "\nBash alias file not found, creating."
		# create file
		touch "${alias_file}"

	fi
	
	# create alias for easy use of command
	alias_check=$(cat "${alias_file}" | grep chroot-${target})

	
	if [[ "$alias_check" == "" ]]; then
	
		cat <<-EOF >> "${alias_file}"
		
		# chroot alias for ${target}
		alias chroot-${target}='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
	
	fi
	
	# source bashrc to update.
	# bashrc should source /home/$user/.bash_${chroot_dir}es
	# can't source form .bashrc, since they use ~ instead of $HOME
	# source from /home/$user/.bash_${chroot_dir}es instead
	
	#source "/home/$user/.bashrc"
	source "${alias_file}"
	
	# enter chroot to test
	# only offer to remain a standard chroot for SteamOS, since it is the only
	# chroot that currently offers post-creation steps
	

	# output summary
	cat <<-EOF
	
	------------------------------------------------------------
	Summary
	------------------------------------------------------------
	
	You will now be placed into the chroot. Press [ENTER].
	Any available post install scritps will now launch to configure a basic setup or 
	more advanced optoins (e.g. SteamOS). Please hit [ENTER] now. 
	
	You may use 'sudo /usr/sbin/chroot /home/desktop/chroots/${target}' to 
	enter the chroot again. You can also use the newly created ${chroot_dir} listed below
	
	EOF

	echo -e "\tchroot-${target}\n"
	
	# Capture input for enter
	read ENTER_KEY

	# copy over post install scripts for execution on the SteamOS chroot
	echo -e "==> Copying post install scripts to tmp directory\n"
	
	cp "${type}-chroot-post-install.sh" "${chroot_dir}/tmp/"
	cp ../gpg-import.sh "${chroot_dir}/tmp/"
	
	# mark executable
	chmod +x "${chroot_dir}/tmp/${type}-chroot-post-install.sh"
	chmod +x "${chroot_dir}/tmp/${type}-chroot-post-install.sh"
	
	# modify gpg-import.sh with sudo removed, as it won't be configured and we
	# don't need it to be there
	sed -i "s|sudo ||g" "${chroot_dir}/tmp/gpg-import.sh"
	
	# Modify type based on opts in post-install script
	sed -i "s|"tmp_type"|${type}|g" "${chroot_dir}/tmp/${type}-chroot-post-install.sh"
	
	# modify release_tmp in post-install script
	sed -i "s|"tmp_release"|${release}|g" "${chroot_dir}/tmp/${type}-chroot-post-install.sh"
	
	# modify arch_tmp in post-install script
	sed -i "s|"tmp_arch"|${arch}|g" "${chroot_dir}/tmp/${type}-chroot-post-install.sh"
	
	# "bind" /dev/pts
	mount --bind /dev/pts "${chroot_dir}/dev/pts"
	
	# run script inside chroot with:
	# chroot /chroot_dir /bin/bash -c "su - -c /tmp/test.sh"
	/usr/sbin/chroot "${chroot_dir}" /bin/bash -c "/tmp/${type}-chroot-post-install.sh"
	
	# Unmount /dev/pts
	umount ${chroot_dir}/dev/pts
	
	#####################################################
	# Permissions
	#####################################################
	
	#Correct permissions since we are running with sudo
	sudo chown -R $user:$user "${chroot_dir}"
	sudo chown $user:$user "${alias_file}"
}

main()
{
	
	clear
	check_sources
	funct_prereqs
	funct_set_target
	funct_set_arch
	funct_create_chroot
	
}

#####################################################
# Main
#####################################################

# Start main script if above checks clear
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

