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
operation=$1
system=$2
romlist=$3
archive="${HOME}/Emulation/roms/archive/${system}"

if [[ -z "${operation}" ]]; then
	echo "[ERROR] Missing operation as arg 1! One of: archive, unarchive"
	exit 1
fi
if [[ -z "${system}" ]]; then
	echo "[ERROR] Missing system name as arg 2! E.g. 'mame', 'psp'"
	exit 1
fi
if [[ -z "${romlist}" ]]; then
	echo "[ERROR] Missing rom list to parse as arg 2!"
	exit 1
fi
if [[ ! -d "${archive}" ]]; then
	echo "[ERROR] Archive dir ${archive} does not exist!"
	exit 1
fi

# Set src/dest
if [[ "${operation}" == "unarchive" ]]; then
	dest="${PWD}"
	src="${archive}"

elif [[ "${operation}" == "archive" ]]; then
	dest="${archive}"
	src="${PWD}"
else
	echo "[ERROR] Invalid operation!"
	exit 1
fi

# Move
roms_to_move=()
num_roms=$(cat "${romlist}" | wc -l)
echo "[INFO] This operation will move ${num_roms} ROM from ${src} to ${dest}"
read -erp "[INFO] Proceed? (y/N): " response
if [[ "${response}" != "y" ]]; then
	echo "[INFO] Aborting..."
	exit 0
fi

for rom in $(cat "${romlist}");
do
	rom_file=$(find "${src}" -name "${rom}")
	if [[ -z "${rom_file}" ]]; then
		echo "[ERROR] Could not find ROM(s) ${rom}, skipping"
		continue
	fi
	rom_file_no_ext=$(basename $(echo "${rom_file}" | sed 's/.zip//'))

	##############################
	# Special handling
	##############################
	
	# MAME
	if [[ "${system}" == "mame" ]]; then
		chd_folder=$(find "${src}" -type d -name "${rom_file_no_ext}")
		echo "Moving ROM from list: $rom to $dest"
		mv "${rom_file}" "${dest}"
		if [[ -n "${chd_folder}" ]]; then
			echo "Moving ROM CHD folder/files from list: $chd_folder to $dest"
			mv "${chd_folder}" "${dest}/"
		fi
	fi
done

