#!/bin/bash

# Download qtsixad or sixpair:
# This is a rebuilt deb package from the ppa:falk-t-j/qtsixa PPA
wget -P /tmp "http://www.libregeek.org/SteamOS-Extra/<PS3 PKG LINK HERE>"

echo -e "\nConnect the PS3 Controller with USB to your SteamOS Machine.\n"

#Pair the controller with the bluetooth dongle.

sudo ./sixpair

# Install and start sixad daemon.
sudo dpkg -i sixad_20131215-1_amd64.deb
sudo update-rc.d sixad defaults
sudo /etc/init.d/sixad start

echo -e "\nDisconnect the PS3 Controller from USB and press the PS button now"
echo -e "The controller should connect and light up player 1 at a minimum."
echo -e "\nUsing the left stick and pressing the left and right stick navigate to the Settings Screen 
and edit the layout of the controller."
