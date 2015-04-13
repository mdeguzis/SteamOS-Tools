#!/bin/bash

# made to kick off the config with in the chroot.
# http://www.cyberciti.biz/faq/unix-linux-chroot-command-examples-usage-syntax/

# set vars
policy="./usr/sbin/policy-rc.d"

# set targets / defaults
tmp_target="default"
beta_opt_in="beta_tmp"
stock_opt="stock_tmp"

# bail out if strock opt was changed to yes in ./build-test-chroot
if [[ "$stock_opt" == "yes" ]]; then
	# exit post install
	echo -e "User requested no post-install configuration. Exiting...\n"
	exit
	
elif [[ "$stock_opt" == "no" ]]; then
	echo -e "The intended target is: ${tmp_target}"
	echo -e "Running post install commands now...\n"
	sleep 1s
else
	echo -e "Failture to obtain stock status, exiting"
	exit
	
fi

if [[ "$tmp_target" == "steamos" || "$tmp_target" == "steamos-beta" ]]; then
	
	# pass to ensure we are in the chroot 
	# temp test for chroot (output should be something other than 2)
	ischroot=$(ls -di /)
	
	if [[ "$ischroot" != "2" ]]; then
		echo "We are chrooted!"
		sleep 2s
	else
	echo -e "\nchroot entry failed. Exiting...\n"
		sleep 2s
		exit
	fi
	
	# opt into beta in chroot if flag is thrown
	
	if [[ "$beta_opt_in" == "yes" ]]; then
	# add beta repo and update
		echo -e "Opt into beta? [YES]\n"
		apt-get install steamos-beta-repo -y
		apt-get update -y
		apt-get upgrade -y
		  
	elif [[ "$beta_opt_in" == "no" ]]; then
		# do nothing
		echo -e "\nOpt into beta? [NO]\n"
	else
		# failure to detect var
		echo -e "\nFailed to detect beta opt in! Exiting..."
		exit
	fi
	
	# create dpkg policy for daemons
	cat <<-EOF > ${policy}
	!/bin/sh
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
	
	# "bind" /dev/pts
	mount --bind /dev/pts /home/desktop/${target}-chroot/dev/pts
	
	# eliminate unecessary packages
	apt-get -t wheezy install deborphan
	deborphan -a
	
	# exit chroot
	echo -e "\nExiting chroot!\n"
	exit
	
	sleep 2s
	
elif [[ "$tmp_target" == "wheezy" ]]; then

	# do nothing for now
	echo "" > /dev/null
fi
