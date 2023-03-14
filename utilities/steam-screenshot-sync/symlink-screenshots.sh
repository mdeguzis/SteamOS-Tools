#!/bin/bash
# rclone cannot currently sync with "flattened" files (no dirs)
# It's possible a new version will provide a flatten option or something
# Do not sync useless thumbnails directory
#
# The trick right now is create symlinks to all the screenshots to ~/.steam_screenshots
# It's lame/messy, but it gets the job done

set -e

main() {
	echo "[INFO] symlinking screenshots"
	SOURCE_DIR="${HOME}/.steam_screenshots"
	mkdir -p "${SOURCE_DIR}"

	# Crude Google Photos > local sync for deleted photos
	# If this is too unstable, this may be removed
        echo "[INFO] 'Syncing' back from Google Photos what was deleted"
        lfiles=$(find ${SOURCE_DIR} -name *.jpg -exec $(echo basename {}) \; | tr -s '\n' ' ')
        gfiles=()
        for f in $(~/.local/bin/rclone lsf gphoto:album/Steam-screenshots);
        do
                gfiles+=("${f}")
        done
        to_remove_local=$(echo ${gfiles[@]} ${lfiles} | tr ' ' '\n' | sort | uniq -u)
        for t in ${to_remove_local};
        do
                # Remove actual file + symlink
                echo "[INFO] Pruning ${SOURCE_DIR}/${t} that is not found in remote album"
                rm -fv "$(readlink -f ${SOURCE_DIR}/${t})"
                rm -fv "${SOURCE_DIR}/${t}"
        done

	echo "[INFO] Linking Steam screnshots to ${SOURCE_DIR}"
	for d in $(find -L ${HOME}/.local/share/Steam/userdata/ -type d -name "screenshots" -not -path '*thumbnails*');
	do
		# Link
		for f in $(find -L ${d} -type f -name "*.jpg" -not -path '*thumbnails*');
		do
			ln -sfv ${f} ${SOURCE_DIR}/$(basename ${f})
		done
	done

	# Cleanup links that have no target anymore
	echo "[INFO] Cleaning up old broken symlinks"
	for l in $(find ${SOURCE_DIR} -name "*.jpg");
	do
		if [[ ! -f $(readlink -f ${l}) ]]; then
			rm -fv ${l}
		fi
	done

}
main 2>&1 | tee /tmp/sync-screenshots-linker.log
echo "[INFO] Done! See /tmp/sync-screenshots-linker.log"
