#!/bin/bash
# Credit: https://foosel.net/til/how-to-automatically-sync-screenshots-from-the-steamdeck-to-google-drive/

set -e

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
	SOURCE_DIR="${HOME}/.steam-screenshots"

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

		echo "[INFO] Creating Google Photos album: ${REMOTE_IDR}"
		~/.local/bin/rclone mkdir gphoto:${REMOTE_DIR}

		echo "[INFO] Copyign source code to ~/steam-screenshot-sync"
		mkdir -p ~/steam-screenshot-sync
		cp -rv . ~/steam-screenshot-sync

		echo "[INFO] Configuring new systemd unit files"
		cp -v systemd/* ~/.config/systemd/user/

		echo "[INFO] Installing and activating systemd unit files"
		systemctl --user enable --now sync-screenshots.path
		systemctl --user status sync-screenshots.path

		# Symlinking service to workaround forced target directories in Google Photos
		systemctl --user enable --now sync-screenshots-linker.service
		systemctl --user status sync-screenshots-linker.service
		systemctl --user enable --now sync-screenshots-linker.timer
		systemctl --user status sync-screenshots-linker.timer

		# Main service
		systemctl --user enable --now sync-screenshots.service
		systemctl --user status sync-screenshots.service

		systemctl --user daemon-reload

	elif [[ "${action}" == "uninstall" ]]; then
		systemctl --user disable --now sync-screenshots.path
		systemctl --user disable --now sync-screenshots.service
		systemctl --user disable --now sync-screenshots-linker.timer
		systemctl --user disable --now sync-screenshots-linker.service
		systemctl --user daemon-reload
		rm -v ~/.config/systemd/user/sync-screenshots*

	elif [[ "${action}" == "run" ]]; then
		# Do not run sync when the linker is running
		# This could result in an imbalance between local/remote, wherein
		# A file is being removed/added while a sync kicks off
		echo "[INFO] Checking for active linker actions..."
		while pgrep -lf ".*bash.*symlink-screenshots.sh";
		do
			echo "[ERROR] Symlinker is currently runnig, waiting until it is done..."
			sleep 5s
		done

		# Add a crude "sync back" that checks the remote listing then compares
		# what is in ~/.steam-screenshots to try and achieve a "bi-directional"
		# sync.  Results will be matched and deleted from the real path

		echo "[INFO] Syncing screenshots from ${SOURCE_DIR} to ${REMOTE_DIR}, please wait..."
		~/.local/bin/rclone sync -vv -L -P "${SOURCE_DIR}" "${REMOTE_NAME}:${REMOTE_DIR}" \
			--exclude=**/thumbnails/**
	else
		echo "[ERROR] Unknown action: ${action}. Please use one of: install, uninstall, run"
		exit 1
	fi

	echo "[INFO] Done!"
}

# start and log
action=$1
main ${action} 2>&1 | tee "/tmp/sync-screenshots.log"
echo "[INFO] Log: /tmp/sync-screenshots.log"
