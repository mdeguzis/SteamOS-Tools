#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	install-desktop-software.sh
# Script Ver:	0.3.1
# Description:	simple script to test controllers with xboxdrv. Reboot to reset
#               your system setup. Mainly for testing only
# Usage:      ./xboxdrv.sh
# -------------------------------------------------------------------------------

sudo rmmod xpad

xboxdrv \
    --daemon \
    --silent \
    --dbus session \
    --controller-slot 0 \
    --trigger-as-button \
    --ui-axismap x2=ABS_Z,y2=ABS_RZ \
    --ui-buttonmap A=BTN_B,B=BTN_X,X=BTN_A,TR=BTN_THUMBL,TL=BTN_MODE,GUIDE=BTN_THUMBR \
    --next-controller \
    --trigger-as-button \
    --ui-axismap x2=ABS_Z,y2=ABS_RZ \
    --ui-buttonmap A=BTN_B,B=BTN_X,X=BTN_A,TR=BTN_THUMBL,TL=BTN_MODE,GUIDE=BTN_THUMBR
