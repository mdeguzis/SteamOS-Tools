#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	steamos-chroot-post-install.sh
# Script Ver:	0.6.9
# Description:	made to kick off the config with in the chroot.
#               See: https://wiki.debian.org/chroot
# Usage:	N/A - called by build-test-chroot
#
# Warning:	This post-install script needs A LOT* OF WORK!!!!
# 		The end goal is to replicate the setup of SteamOS as
# 		closely as possible in a chroot container. If Bob
#		the builder can do it, so can we :)
#
#		TODO: checkout Steam's post install script from the installer
# -------------------------------------------------------------------------------

# This post-isntall scripts needs A LOT OF WORK!!!!
# The end goal is to replicate the setup of SteamOS as
# closely as possible

# test user
current_user=$(whoami)
echo -e "The current user is: $current_user"
sleep 1s

# set vars
policy="./usr/sbin/policy-rc.d"

# set targets / defaults
# These options are set set in the build-chroot script
# options set for failure notice in evaluation below
type="tmp_type"
stock_opt="tmp_stock"
release="tmp_release"
arch="tmp_arch"
target="${type}-${release}-${arch}"
	
# pass to ensure we are in the chroot 
# temp test for chroot (output should be something other than 2)
ischroot=$(ls -di /)

echo -e "\nChecking for chroot..."

if [[ "$ischroot" != "2" ]]; then

	echo "We are chrooted!"
	sleep 2s
	
else

	echo -e "\nchroot entry failed. Exiting...\n"
	sleep 2s
	exit
fi

# steamos chroot seems to be missing 'locales' and 'less', ensure they are installed
if ! apt-get install -y --force-yes locales; then

	echo -e "Could not install basic packages. Exiting."
	exit 1
	
fi

cat<<- EOF

==> Generating locale...
    You will now be shown a listing of the available locales.
    Please enter your select in the format "aa_AA".
    Please press a key to continue
    
EOF

# Regenerate locales
dpkg-reconfigure locales
	
echo -e "\n==> Configuring users and groups"

# Add groups not included in Debian base
groupadd bluetooth -g 115
groupadd pulse-access -g 121
groupadd desktop
groupadd steam

if [[ "$release" == "alchemist" ]]; then

	# missing groups in Alchemist release
	groupadd netdev
	
fi

# User configurations
useradd -s /bin/bash -m -d /home/desktop -c "Desktop user" -g desktop desktop
useradd -s /bin/bash -m -d /home/steam -c "Steam user" -g steam steam

# add additional groups
usermod -a -G cdrom,floppy,sudo,audio,dip,video,plugdev,netdev,bluetooth,pulse-access desktop
usermod -a -G audio,dip,video,plugdev,netdev,bluetooth,pulse-access steam

# setup rootuser pw
echo -e "\n###########################"
echo -e "Set root user password"
echo -e "###########################\n"

pw_set=$(passwd -S root | cut -f2 -d " " 2> /dev/null)
while [[ "$pw_set" == "" || "$pw_set" == "L" ]];
do
	passwd root
done

# setup steam user

echo -e "\n###########################"
echo -e "Set steam user password"
echo -e "###########################\n"

pw_set=$(passwd -S steam | cut -f2 -d " " 2> /dev/null)
while [[ "$pw_set" == "" || "$pw_set" == "L" ]];
do
	passwd steam
done

# Above, we allow users to choose their own password.
# Below, we could echo the default passwords for them, if desired
# echo -e "steam\nsteam\n" | passwd steam 

# setup desktop user
#su - desktop
echo -e "\n###########################"
echo -e "Set desktop user password"
echo -e "###########################\n"

pw_set=$(passwd -S desktop | cut -f2 -d " " 2> /dev/null)
while [[ "$pw_set" == "" || "$pw_set" == "L" ]];
do
	passwd desktop
done

# Above, we allow users to choose their own password.
# Below, we could echo the default passwords for them, if desired
# echo -e "steam\nsteam\n" | passwd desktop 

# Change to root to handle configurations
# echo -e "\n==> Changing to root for system setup\n"
# su - root

# Change to root chroot folder
cd /

###########################################
# TO DO MORE HERE. NEEDS CONFIG FILES
###########################################

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

# configure the repository sources below, as it doesn't seem debootstrap
# can assign deb-src lines

if [[ "$release" == "alchemist" ]]; then

	# chroot has deb line, but not deb-src, add it
	# Also src line from pool is not complete, missing contrib/non-free
	cat <<-EOF > /etc/apt/sources.list
	deb http://repo.steampowered.com/steamos alchemist main contrib non-free
	deb-src http://repo.steampowered.com/steamos alchemist main contrib non-free
	EOF

	# Enable Debian wheezy repository
	cat <<-EOF > /etc/apt/sources.list.d/wheezy.list
	deb http://http.debian.net/debian/ wheezy main
	EOF
	
elif [[ "$release" == "alchemist" && "$type" == "steamos-beta" ]]; then

	# BETA OPT IN

	# chroot has deb line, but not deb-src, add it
	# Also src line from pool is not complete, missing contrib/non-free
	
	cat <<-EOF > "/etc/apt/sources.list"
	deb http://repo.steampowered.com/steamos alchemist main contrib non-free
	deb-src http://repo.steampowered.com/steamos alchemist main contrib non-free
	EOF
	
	# beta repo
	cat <<-EOF > "/etc/apt/sources.list.d/steamos-beta-repo.list"
	# SteamOS repo for alchemist_beta public beta test repository
	deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free
	EOF

	# Enable Debian wheezy repository
	cat <<-EOF > "/etc/apt/sources.list.d/wheezy.list"
	deb http://http.debian.net/debian/ wheezy main
	EOF

elif [[ "$release" == "brewmaster" ]]; then

	# chroot has deb line, but not deb-src, add it
	# Also src line from pool is not complete, missing contrib/non-free
	
	cat <<-EOF > "/etc/apt/sources.list"
	deb http://repo.steampowered.com/steamos brewmaster main contrib non-free
	deb-src http://repo.steampowered.com/steamos brewmaster main contrib non-free
	EOF
	
	# Enable Debian jessie repository
	cat <<-EOF > "/etc/apt/sources.list.d/jessie.list"
	deb http://http.debian.net/debian/ jessie main
	EOF
	
elif [[ "$release" == "brewmaster" && "$type" == "steamos-beta" ]]; then

	# BETA OPT IN

	# chroot has deb line, but not deb-src, add it
	# Also src line from pool is not complete, missing contrib/non-free
	
	cat <<-EOF > "/etc/apt/sources.list"
	deb http://repo.steampowered.com/steamos brewmaster main contrib non-free
	deb-src http://repo.steampowered.com/steamos brewmaster main contrib non-free
	EOF
	
	# beta repo
	cat <<-EOF > "/etc/apt/sources.list.d/steamos-beta-repo.list"
	# SteamOS repo for brewmaster_beta public beta test repository
	deb http://repo.steampowered.com/steamos brewmaster_beta main contrib non-free
	EOF

	# Enable Debian wheezy repository
	cat <<-EOF > "/etc/apt/sources.list.d/jessie.list"
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

echo -e "\n==> Adding keyrings\n"
sleep 1s

apt-get install -y debian-archive-keyring

echo -e "\n==> Adding gpg keys\n"

# Alchemist needs GPG keys imported
if [[ "$release" == "alchemist" ]]; then

	# import Alchemist gpg key
	/tmp/gpg-import.sh 7DEEB7438ABDDD96 2> /dev/null 
	# import Alchemist gpg key
	/tmp/gpg-import.sh 7638D0442B90D010 2> /dev/null
	
fi

echo -e "\n==> Updating system\n"
sleep 1s

# Update apt
apt-get update
apt-key update

echo -e "\n==> Instaling packages for testing and building\n"
sleep 1s

deps="git devscripts build-essential checkinstall debian-keyring \
debian-archive-keyring cmake g++ g++-multilib libqt4-dev libqt4-dev \
libxi-dev libxtst-dev libX11-dev bc gcc gcc-multilib sudo"

for dep in ${deps}; do
	pkg_chk=$(dpkg-query -s ${dep})
	if [[ "$pkg_chk" == "" ]]; then
	
		echo -e "\n==INFO==\nInstalling package: ${dep}\n"
		sleep 1s
		apt-get install -y ${dep}
		
		if [[ $? = 100 ]]; then
			echo -e "Cannot install ${dep}. Please install this manually \n"
			sleep 3s
		fi
		
	else
		echo "package ${dep} [OK]"
		sleep .3s
	fi
done

# change sudo timeout
echo -e "\nDefaults:desktop timestamp_timeout=10" >> /etc/sudoers

#echo -e "\n==> Cleaning up packages\n"
#sleep 1s

# eliminate unecessary packages
# disable for further testing
# deborphan -a

# exit chroot
echo -e "\nExiting chroot!\n"
echo -e "You may use 'sudo /usr/sbin/chroot /home/desktop/chroots/${target}' to 
enter the chroot again. You can also use the newly created alias listed below\n"
echo -e "\tchroot-${target}\n"

sleep 2s
exit


elif [[ "$tmp_type" == "debian" ]]; then

	# do nothing for now
	echo "" > /dev/null

fi
