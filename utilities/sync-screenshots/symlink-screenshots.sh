#!/bin/bash
# rclone cannot currently sync with "flattened" files (no dirs)
# It's possible a new version will provide a flatten option or something
# Do not sync useless thumbnails directory
#
# The trick right now is create symlinks to all the screenshots to ~/.steam_screenshots
# It's lame/messy, but it gets the job done

set -e

echo "[INFO] symlinking screenshots"
mkdir -p ~/.steam_screenshots

for d in $(find -L ${HOME}/.local/share/Steam/userdata/ -type d -name "screenshots" -not -path '*thumbnails*');
do
	# Link
	for f in $(find -L ${d} -type f -name "*.jpg" -not -path '*thumbnails*');
	do
		ln -sf ${f} ${HOME}/.steam_screenshots/$(basename ${f})
	done

	# Cleanup links that have no target anymore
	echo "[INFO] Cleaning up old broken symlinks"
	for l in $(find ~/.steam_screenshots -name "*.jpg");
	do
		if [[ ! -f $(readlink -f ${l}) ]]; then
			rm -fv ${l}
		fi
	done
done
