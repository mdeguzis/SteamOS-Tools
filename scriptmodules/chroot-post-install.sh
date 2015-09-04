#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	chroot-post-install.sh
# Script Ver:	0.2.7
# Description:	made to kick off the config with in the chroot.
#               See: https://wiki.debian.org/chroot
# Usage:	N/A
#
# Warning:	This post-isntall scripts needs A LOT* OF WORK!!!!
# 		The end goal is to replicate the setup of SteamOS as
# 		closely as possible.
#
#		TODO: checkout Steam's post install script from the installer
# -------------------------------------------------------------------------------

# 
# This post-isntall scripts needs A LOT OF WORK!!!!
# The end goal is to replicate the setup of SteamOS as
# closely as possible

# set vars
policy="./usr/sbin/policy-rc.d"

# set targets / defaults
# These options are set set in the build-chroot script
# options set for failure notice in evaluation below
type="tmp_type"
beta_opt_in="tmp_beta"
stock_opt="tmp_stock"
release="tmp_release"
full_target="${type}_${release}"

# bail out if strock opt was changed to yes in ./build-test-chroot
if [[ "$stock_opt" == "yes" ]]; then

	# exit post install
	echo -e "User requested no post-install configuration. Exiting...\n"
	exit
	
elif [[ "$stock_opt" == "no" ]]; then

	echo -e "The intended target is: ${type} (${release})"
	echo -e "Running post install commands now..."
	sleep 2s
	
else
	echo -e "Failture to obtain stock status, exiting"
	exit
	
fi

if [[ "$type" == "steamos" || "$type" == "steamos-beta" ]]; then
	
	# pass to ensure we are in the chroot 
	# temp test for chroot (output should be something other than 2)
	ischroot=$(ls -di /)
	
	echo "Checking for chroot..."
	
	if [[ "$ischroot" != "2" ]]; then
	
		echo "We are chrooted!"
		sleep 2s
		
	else
	
		echo -e "\nchroot entry failed. Exiting...\n"
		sleep 2s
		exit
	fi
	
	echo -e "\n==> Configuring users and groups"
	
	# Add groups not included in Debian base
	groupadd bluetooth -g 115
	groupadd pulse-access -g 121
	groupadd desktop
	groupadd steam
	
	# User configurations
	useradd -s /bin/bash -m -d /home/desktop -c "Steam Desktop" -g desktop desktop
	useradd -s /bin/bash -m -d /home/steam -c "Steam Desktop" -g steam steam
	
	# add additional groups
	usermod -a -G cdrom,floppy,sudo,audio,dip,video,plugdev,netdev,bluetooth,pulse-access desktop
	usermod -a -G audio,dip,video,plugdev,netdev,bluetooth,pulse-access steam
	
	# setup sudo file
	# TODO
	
	# setup steam user
	#su - steam
	echo -e "\n###########################"
	echo -e "Set steam user password"
	echo -e "###########################\n"
	passwd steam
	
	# Above, we allow users to choose their own password.
	# Below, we could echo the default passwords for them, if desired
	# echo -e "steam\nsteam\n" | passwd steam 
	
	# setup desktop user
	#su - desktop
	echo -e "\n#############################"
	echo -e "Set desktop user password"
	echo -e "#############################\n"
	passwd desktop
	
	# Above, we allow users to choose their own password.
	# Below, we could echo the default passwords for them, if desired
	# echo -e "steam\nsteam\n" | passwd desktop 
	
	# Change to root chroot folder
	cd /
	
	###########################################
	# TO DO MORE HERE. NEEDS CONFIG FILES
	###########################################
	
	# opt into beta in chroot if flag is thrown
	
	if [[ "$beta_opt_in" == "yes" ]]; then
	# add beta repo and update
		
		echo -e "Opt into beta? [YES]\n"
	
		# import GPG key
		cd /home/desktop
		gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --recv-keys 7DEEB7438ABDDD96
		exit
		
		# update and upgrade
		apt-key update
		apt-get update -y
		apt-get install steamos-beta-repo -y
		apt-get upgrade -y
		  
	elif [[ "$beta_opt_in" == "no" ]]; then
	
		# do nothing
		echo -e "\nOpt into beta? [NO]\n"
		
	else
	
		# failure to detect var
		echo -e "\nFailed to detect beta opt in! Exiting..."
		exit
		
	fi
	
	echo -e "\n==> Creating package policy\n"
	
	# create dpkg policy for daemons
	cat <<-EOF > ${policy}
	#!/bin/sh
	exit 101
	EOF
	
	# mark policy executable
	chmod a+x ./usr/sbin/policy-rc.d
	
	# Several packages depend upon ischroot for determining correct 
	# behavior in a chroot and will operate incorrectly during upgrades if it is not fixed.
	dpkg-divert --divert /usr/bin/ischroot.debianutils --rename /usr/bin/ischroot
	
	if [[ -f "/usr/bin/ischroot" ]]; then
		# remove link
		/usr/bin/ischroot
	else
		ln -s /bin/true /usr/bin/ischroot
	fi
	
	echo -e "\n==> Configuring repository sources"
	
	if [[ "$release" == "alchemist" ]]; then
	
		# Enable Debian wheezy repository
		cat <<-EOF > /etc/apt/sources.list.d/wheezy.list
		deb http://http.debian.net/debian/ jessie main
		EOF
	
	elif [[ "$release" == "brewmaster" ]]; then
	
		# brewmaster chroot has deb line, but not deb-src, add it
		# Also src line from pool is not complete, missing contrib/non-free
		cat <<-EOF > /etc/apt/sources.list
		deb http://repo.steampowered.com/steamos brewmaster main contrib non-free
		deb-src http://repo.steampowered.com/steamos brewmaster main contrib non-free
		EOF
		
		# Enable Debian jessie repository
		cat <<-EOF > /etc/apt/sources.list.d/wheezy.list
		deb http://http.debian.net/debian/ jessie main
		EOF
	
	fi
	
	# Enable pinning for SteamOS repo
	cat <<-EOF > /etc/apt/preferences.d/steamos
	Package: *
	Pin: release l=SteamOS
	Pin-Priority: 900
	EOF
	
	# Enable pinning for Debian repo
	cat <<-EOF > /etc/apt/preferences.d/debian
	Package: *
	Pin: release l=Debian
	Pin-Priority: 100
	EOF
	
	echo -e "\n==> Updating system\n"
	
	# Update apt
	apt-get update -y
	
	echo -e "\n==> Cleaning up packages"
	
	# eliminate unecessary packages
	apt-get install deborphan
	deborphan -a
	
	# create alias for easy use of command
	alias_check_steamos_brew=$(cat "$HOME/.bashrc" | grep chroot-steamos-brewmaster)
	alias_check_debian_wheezy=$(cat "$HOME/.bashrc" | grep chroot-debian-wheezy)
	alias_check_debian_jessie=$(cat "$HOME/.bashrc" | grep chroot-debian-jessie)
	
	if [[ "$alias_check_steamos_brew" == "" ]]; then
	
		cat <<-EOF >> "$HOME/.bashrc"
		
		# chroot alias for ${type} (${target})
		alias chroot-steamos-brewmaster='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
		
	elif [[ "$alias_check_debian_wheezy" == "" ]]; then
	
		cat <<-EOF >> "$HOME/.bashrc"
		
		# chroot alias for ${type} (${target})
		alias chroot-debian-wheezy='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
		
	elif [[ "$alias_check_debian_jessie" == "" ]]; then
	
		cat <<-EOF >> "$HOME/.bashrc"
		
		# chroot alias for ${type} (${target})
		alias chroot-debian-jessie='sudo /usr/sbin/chroot /home/desktop/chroots/${target}'
		EOF
		
	fi
	
	# exit chroot
	echo -e "\nExiting chroot!\n"
	echo -e "You may use '/usr/sbin/chroot /home/desktop/chroots/${target}' to 
enter the chroot again. You can also use the newly created alias listed below\n"

	if [[ "$full_target" == "steamos_brewmaster" ]]; then
	
		echo -e "chroot-steamos-brewmaster"
	
	elif [[ "$full_target" == "debian_wheezy" ]]; then
	
		echo -e "chroot-debian-wheezyr"
		
	elif [[ "$full_target" == "steamos_brewmaster" ]]; then
	
		echo -e "chroot-steamos-wheezy"
		
	fi
	
	exit
	
	sleep 2s
	
elif [[ "$tmp_type" == "debian" ]]; then

	# do nothing for now
	echo "" > /dev/null
	
fi
