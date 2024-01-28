#!/bin/bash
# Credit: https://foosel.net/til/how-to-automatically-sync-screenshots-from-the-steamdeck-to-google-drive/
# Accepts a folder as input that will be synced between a local target and the root of Google drive

set -e

main() {
    local ACTION=$1
    local REMOTE_DIR=$2
    local SOURCE_DIR=$3

	scriptdir=$PWD

	if [[ "${ACTION}" == "install" ]]; then
		echo "[INFO] Creating Google Drive folder: ${REMOTE_IDR} in directory root"
		rclone mkdir gdrive:/${REMOTE_DIR}

		echo "[INFO] Configuring new systemd unit files"
		cp -v systemd/* ~/.config/systemd/user/

		echo "[INFO] Installing and activating systemd unit files"
		systemctl --user enable --now sync-folder.path
		systemctl --user status sync-folder.path

		# Symlinking service to workaround forced target directories in Google Photos
		systemctl --user enable --now sync-folder-linker.service
		systemctl --user status sync-folder-linker.service
		systemctl --user enable --now sync-folder-linker.timer
		systemctl --user status sync-folder-linker.timer

		# Main service
		systemctl --user enable --now sync-folder.service
		systemctl --user status sync-folder.service

		systemctl --user daemon-reload

	elif [[ "${ACTION}" == "uninstall" ]]; then
		systemctl --user disable --now sync-folder.path
		systemctl --user disable --now sync-folder.service
		systemctl --user disable --now sync-folder-linker.timer
		systemctl --user disable --now sync-folder-linker.service
		systemctl --user daemon-reload
		rm -v ~/.config/systemd/user/sync-folder*

	elif [[ "${ACTION}" == "run" ]]; then
		# Do not run sync when the linker is running
		# This could result in an imbalance between local/remote, wherein
		# A file is being removed/added while a sync kicks off
		echo "[INFO] Checking for active linker ACTIONs..."
		while pgrep -lf ".*bash.*symlink-folder.sh";
		do
			echo "[ERROR] Symlinker is currently running, waiting until it is done..."
			sleep 5s
		done

		# Add a crude "sync back" that checks the remote listing then compares
		# what is in ${SOURCE_DIR} to try and achieve a "bi-directional"
		# sync.  Results will be matched and deleted from the real path

		echo "[INFO] Syncing files from ${SOURCE_DIR} to ${REMOTE_DIR}, please wait..."
		rclone sync -vv -L -P "${SOURCE_DIR}" "${REMOTE_NAME}:${REMOTE_DIR}" \
			--exclude=**/thumbnails/**
	else
		echo "[ERROR] Unknown ACTION: ${ACTION}. Please use one of: install, uninstall, run"
		exit 1
	fi

	echo "[INFO] Done!"
}

# start and log
ACTION=$1
SOURCE_DIR=$2
REMOTE_DIR=$2

# Ensure vars are set

main ${ACTION} 2>&1 | tee "/tmp/sync-gdrive-files.log"
echo "[INFO] Log: /tmp/sync-gdrive-files.log"
