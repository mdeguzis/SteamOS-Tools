#!/bin/bash
# rclone cannot currently sync with "flattened" files (no dirs)
# It's possible a new version will provide a flatten option or something
# Do not sync useless thumbnails directory
#
# The trick right now is create symlinks to all the screenshots to ~/.steam_screenshots
# It's lame/messy, but it gets the job done

# This SHOULD allow things to bail if Google Photos listing fails
set -e

main() {
	# Check for active rclone processes
	# Don't run at the same time to avoid conflicts
	echo "[INFO] Checking for active rclone actions..."
	if pgrep -a rclone; then
		echo "[ERROR] Active rclone action in progress, aborting"
		exit
	fi

	echo "[INFO] symlinking screenshots"
	SOURCE_DIR="${HOME}/.steam-screenshots"
	BACKUP_DIR="${HOME}/.steam-screenshots-backup"
	mkdir -p "${SOURCE_DIR}"
	mkdir -p "${BACKUP_DIR}"

	# Crude Google Photos > local sync for deleted photos
	# If this is too unstable, this may be removed
	# What this accomplishes then, is the local path is mutated, which will
	# kick off the systemd path unit file and trigger an upload after everthing here
	# is done. This should then replicate 1:1 between actions local/remote in Album

	# The album must exist and the process to fetch must complete succesfully
	# If the album is empty, abort, something went wrong
        lfiles=$(find ${SOURCE_DIR} -name *.jpg -exec $(echo basename {}) \; | tr -s '\n' ' ')
        gfiles=$(~/.local/bin/rclone lsf gphoto:album/Steam-screenshots)
	gresponse=$?
	echo -e "[INFO] local: ${lfiles[@]}"
	echo -e "[INFO] Gooogle photos: ${gfiles[@]}"

	# Only run this if we have google photos and command completed
	# echo $gresponse
	if [[ "${gresponse}" -eq 0  ]]; then
		echo "[INFO] 'Syncing' back from Google Photos..."
		for t in ${lfiles[@]};
		do
			# If we have a local file, but it's not found in the lits of Google Photos,
			# remove it from local disk after backing it up.
			if [[ -f "${SOURCE_DIR}/${t}" && ! $(echo "${gfiles[@]}" | grep "${t}") ]]; then
				# Remove actual file + symlink
				# Make a backup for this transaction in case anything goes wrong
				echo "[INFO] Pruning ${SOURCE_DIR}/${t} that is not found in remote album"
				echo "[INFO] Backup up files to remove to: ${BACKUP_DIR}"
				cp -v "$(readlink -f ${SOURCE_DIR}/${t})" "${BACKUP_DIR}"
				echo "[INFO] $(rm -fv "$(readlink -f ${SOURCE_DIR}/${t})")"
				echo "[INFO] $(rm -fv "${SOURCE_DIR}/${t}")"
			fi
		done
	else
		echo "[ERROR] Cannot run linker, see error message"
		exit 1
	fi

	echo "[INFO] Linking Steam screnshots to ${SOURCE_DIR}"
	for d in $(find -L ${HOME}/.local/share/Steam/userdata/ -type d -name "screenshots" -not -path '*thumbnails*');
	do
		# Link
		for f in $(find -L ${d} -type f -name "*.jpg" -not -path '*thumbnails*');
		do
			echo "[INFO] $(ln -sfv ${f} ${SOURCE_DIR}/$(basename ${f}))"
		done
	done

	# Cleanup links that have no target anymore
	echo "[INFO] Cleaning up old broken symlinks"
	for l in $(find ${SOURCE_DIR} -name "*.jpg");
	do
		if [[ ! -f $(readlink -f ${l}) ]]; then
			echo "[INFO] $(rm -fv ${l})"
		fi
	done

}
main 2>&1 | tee /tmp/sync-screenshots-linker.log
echo "[INFO] See /tmp/sync-screenshots-linker.log"
