#!/bin/bash

# made to kick off the config with in the chroot.
# http://www.cyberciti.biz/faq/unix-linux-chroot-command-examples-usage-syntax/

# set target
tmp_target="default"

echo -e "The intended target is: ${tmp_target}"
echo -e "Running post install commands now...\n"
sleep 1s

if [[ "$tmp_target" == "steamos" ]]; then
  
  # pass to ensure we are in the chroot 
  if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  	echo "We are chrooted!"
  	sleep 2s
  	exit
  else
  	echo -e "\nchroot entry failed. Exiting...\n"
  	sleep 2s
  	exit
  fi
  
  # opt into beta in chroot if flag is thrown
  if [[ "$beta_flag" == "yes" ]]; then
	# add beta repo and update
  	apt-get install steamos-beta-repo -y
  	apt-get update -y
  	apt-get upgrade -y
  elif [[ "$beta_flag" == "no" ]]; then
  	# do nothing
  	echo "" > /dev/null
  fi
  
  # create dpkg policy for daemons
  cat <<-EOF > ./usr/sbin/policy-rc.d 
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
