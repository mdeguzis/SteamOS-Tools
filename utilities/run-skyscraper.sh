#!/bin/bash

user=$1
pass=$2
system=$3

Skyscraper \
	-f emulationstation \
	-s screenscraper \
	-u $user:$pass \
	-i ~/Emulation/roms/$system \
	-g ~/Emulation/roms/$system \
	-o ~/Emulation/roms/$system \
	-p $system

