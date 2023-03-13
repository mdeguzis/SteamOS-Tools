#!/bin/bash
# Credit: https://foosel.net/til/how-to-automatically-sync-screenshots-from-the-steamdeck-to-google-drive/

main() {
	if [[ -z ${action} ]]; then
		echo "[ERROR] Action must be passed as the first arg! One of: install, run"
		exit 1
	fi
	scriptdir=$PWD
	rclone_ver="1.61.1"
	REMOTE_NAME='gphoto'
	REMOTE_DIR='album/Steam-screenshots'

	# YAY COMPLEX DIRECTORY NUMBERS
	# Find current profiles with 'find ~/.steam/steam/ -name "screenshots"'
	# Also, you can find this in Steam settings
	# Symlink this so the <service>.path is easy and does not change
	SOURCE_DIR="${HOME}/.steam_screenshots"

	if [[ "${action}" == "install" ]]; then
		if ! $(which rclone &>/dev/null); then
			echo -e "[INFO] Missing rclone, installing..."
			mkdir -p ~/rclone
			cd ~/rclone
			if [[ ! -f "rclone-v${rclone_ver}-linux-amd64.zip" ]]; then
				curl -LO https://downloads.rclone.org/v${rclone_ver}/rclone-v${rclone_ver}-linux-amd64.zip
			fi
			unzip -f rclone-v${rclone_ver}-linux-amd64.zip
			ln -sfv $(readlink -f rclone-v${rclone_ver}-linux-amd64/rclone) ~/.local/bin/rclone
			cd ${scriptdir}
		fi

		echo "[INFO] Installing and activating systemd unit files"
		cp -v sync-screenshots.path ~/.config/systemd/user/
		cp -v sync-screenshots.service ~/.config/systemd/user/
		sudo systemctl daemon-reload
		systemctl --user enable sync-screenshots.path
		systemctl --user start sync-screenshots.path
		systemctl --user status sync-screenshots.path

	elif [[ "${action}" == "run" ]]; then
		# rclone cannot currently sync with "flattened" files (no dirs)
		# It's possible a new version will provide a flatten option or something
		# Do not sync useless thumbnails directory
		#
		# The trick right now is create symlinks to all the screenshots to ~/.steam_screenshots
		# It's lame/messy, but it gets the job done

		# I hate this...
		rm -rf ~/.steam_screenshots
		mkdir -p ~/.steam_screenshots
		for d in $(find -L ${HOME}/.local/share/Steam/userdata/ -type d -name "screenshots" -not -path '*thumbnails*');
		do
			# Link
			echo "[INFO] symlinking screenshots"
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

		echo "[INFO] Syncing screenshots from ${SOURCE_DIR} to ${REMOTE_DIR}, please wait..."
		~/.local/bin/rclone sync -L -P "${SOURCE_DIR}" "${REMOTE_NAME}:${REMOTE_DIR}" \
			--exclude=**/thumbnails/**
	else
		echo "[ERROR] Unknown action: ${action}. Please use one of: install, run"
		exit 1
	fi

	echo "[INFO] Done!"
}

# start and log
action=$1
main ${action} 2>&1 | tee "/tmp/sync-screenshots.log"
echo "[INFO] Log: /tmp/sync-screenshots.log"
