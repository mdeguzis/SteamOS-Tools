#!/bin/bash
# Description:
# 	This script can move roms in and out of "roms.archived" in 
# 	the folder it's placed in (e.g. roms/mame). It accepts a txt 
# 	download from http://adb.arcadeitalia.net/lista_mame.php, and 
# 	will match the export against what is in roms.archived or the
# 	current folder (based on operation value or "archive" or "unarchive".
#

# http://adb.arcadeitalia.net/lista_mame.php

# The rom list should have the string to match, one per line
archive="roms.archived"
operation=$1
romlist=$2

if [[ -z "${operation}" ]]; then
	echo "[ERROR] Missing operation as arg 1! One of: archive, unarchive"
	exit 1
fi
if [[ -z "${romlist}" ]]; then
	echo "[ERROR] Missing rom list to parse as arg 2!"
	exit 1
fi

# Set src/dest
if [[ "${operation}" == "unarchive" ]]; then
	dest="${PWD}"
	src="roms.archived"

elif [[ "${operation}" == "archive" ]]; then
	dest="roms.archived"
	src="${PWD}"
else
	echo "[ERROR] Invalid operation!"
	exit 1
fi

# Move
roms_to_move=()
for rom in $(cat "${romlist}");
do
	echo "Adding rom from list: $rom to $dest"
	rom_file=$(find "${src}" -name "${rom}.zip")
	if [[ -z "${rom_file}" ]]; then
		echo "[ERROR] Could not find rom ${rom}, skipping"
		continue
	fi
	mv "${rom_file}" "${dest}"
done

