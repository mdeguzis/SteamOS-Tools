#!/bin/bash

# "Version 2" to take Steam Client corruption into account.
# /usr/bin/steamos-autorepair
# Modified by: Michael DeGuzis <mdeguzis@gmail.com>
#
# <-! #### WIP #### ->
#

# 10s is the time window where systemd stops trying to restart a service
sleep 15

# if lightdm is not running after 15s, it's not a random crash, but many
# otherwise nothing to do, systemd will call us again if it crashes more
if pidof -x lightdm > /dev/null
then
    exit 0
fi

# can't have this be a dependency of our unit or it'll trigger too early
service plymouth-reboot start

plymouth display-message --text="SteamOS is attempting to recover from a fatal error"
plymouth system-update --progress=10

# Configure  packages  which  have  been  unpacked,  but  not  yet configured. Use -a 
# so all unpacked, but unconfigured packages, are configured.
dpkg --configure -a

# Reset the Steam client
su - steam -c '/usr/bin/steam --reset'
plymouth system-update --progress=30

# If the tenfoot folder is missing, we need to get that back
# It may just be best to run steam on the CLI and let it update:
apt-get install -y xvfb &> /dev/null
sudo su - steam -c '/usr/bin/xvfb-run -a -e /tmp/steam_update_log.txt /usr/bin/steam'
plymouth system-update --progress=40

# Attempt to fix broken packages with apt
apt-get -f -y install
plymouth system-update --progress=50

#
# force rebuild dkms modules
#
dkms_modules=`find /usr/src -maxdepth 2 -name dkms.conf`
arr=($dkms_modules)
let prog=50

# compute how far to move the progress bar for each module
let delta="50/${#arr[@]}"

for i in $dkms_modules
do
  module_name=`grep ^PACKAGE_NAME $i | cut -d= -f2 | tr -d \"`
  module_version=`grep ^PACKAGE_VERSION $i | cut -d= -f2 | tr -d \"`

  dkms remove $module_name/$module_version --all
  dkms build -m $module_name -v $module_version
  dkms install -m $module_name -v $module_version
  let prog="$prog + $delta"
  plymouth system-update --progress=$prog
done

plymouth system-update --progress=100
plymouth display-message --text="Recovery complete, restarting..."

sleep 1

reboot
