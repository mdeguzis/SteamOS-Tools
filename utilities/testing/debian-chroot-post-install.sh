#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	       Michael DeGuzis
# Git:		         https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:   	 debian-chroot-post-install.sh
# Script Ver:	     0.5.7
# Description:	   made to kick off the config with in the chroot.
#                  See: https://wiki.debian.org/chroot
# Usage:	         N/A - called by build-test-chroot
#
# -------------------------------------------------------------------------------

# test user
current_user=$(whoami)
echo -e "\nThe current user is: $current_user"
sleep 1s

# set vars
policy="./usr/sbin/policy-rc.d"

# set targets / defaults
# These options are set set in the build-chroot script
# options set for failure notice in evaluation below

type="tmp_type"
release="tmp_release"
target="${type}-${release}"
	
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

cat<<- EOF
==> Generating locale...
    You will now be shown a listing of the available locales.
    Please enter your select in the format "aa_AA".
    Please press a key to continue
    
EOF

# dummy key press
read ENTER_KEY

# show locales
ls /usr/share/i18n/locales | less

# get user choice
read -erp "Desired locale: " locale

# generation locale with choice, fall back to en_US if none-specified
if [[ "$locale" != "" ]]; then
	
	# generate based on choice
	locale-gen "${locale}.UTF-8"
	
else
	# fallback to english, US
	locale-gen "en_US.UTF-8"
fi

echo -e "\n==> Configuring users and groups"

# Add groups that we need created
# group 'users' should already exist.

groupadd bluetooth
groupadd pulse-access

# User configurations
useradd -s /bin/bash -m -d /home/desktop -c "Desktop user" -g users user

# add additional groups
usermod -a -G cdrom,floppy,sudo,audio,dip,video,plugdev,netdev,bluetooth,pulse-access user

# setup desktop user
echo -e "\n###########################"
echo -e "Set root password"
echo -e "###########################\n"
passwd root

# setup steam user
#su - steam
echo -e "\n###########################"
echo -e "Set user  password"
echo -e "###########################\n"
passwd user

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

echo -e "\n==> Updating system\n"
sleep 2s

# Update apt
apt-get update

echo -e "\n==> Instaling some basic packages\n"
sleep 1s

# install some basic package

deps="git devscripts build-essential checkinstall debian-keyring \
debian-archive-keyring cmake g++ g++-multilib libqt4-dev libqt4-dev \
libxi-dev libxtst-dev libX11-dev bc libsdl2-dev gcc gcc-multilib sudo"

for dep in ${deps}; do
	pkg_chk=$(dpkg-query -s ${dep})
	if [[ "$pkg_chk" == "" ]]; then
	
		echo -e "\n==INFO==\nInstalling package: ${dep}\n"
		sleep 1s
		apt-get install ${dep} -y
		
		if [[ $? = 100 ]]; then
			echo -e "Cannot install ${dep}. Please install this manually \n"
			sleep 5s
		fi
		
	else
		echo "package ${dep} [OK]"
		sleep .3s
	fi
done

# change sudo timeout
echo -e "\nDefaults:user timestamp_timeout=10" >> /etc/sudoers

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

