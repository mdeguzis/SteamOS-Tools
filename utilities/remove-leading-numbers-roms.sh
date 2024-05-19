#!/bin/bash
# Description: Trim leading [0-9]{3} leading numbers from rom fils (ANNOYING)

TARGET_DIR=$1
SCRIPTDIR="${PWD}"

find "${TARGET_DIR}" -type f -regextype sed -regex '.*/[0-9]\{3\}\ .*' | \
while read filename;
do
	echo "[INFO] Processing ${filename}"
	basefile=$(basename "${filename}")
	basedir=$(dirname "${filename}")
	cd "${basedir}"
	echo "[INFO] renaming '${basefile}'"
	rename 's/^[0-9]{1,3}\ //' """${basefile}"""
	cd "${SCRIPTDIR}"
done
