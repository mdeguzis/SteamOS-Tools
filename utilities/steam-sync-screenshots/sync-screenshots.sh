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

		echo "[INFO] Copyign source code to ~/steam-screenshots-sync"
		mkdir -p ~/steam-screenshots-sync
		cp -rv . ~/steam-screenshots-sync

		echo "[INFO] Configuring new systemd unit files"
		cp -v systemd/* ~/.config/systemd/user/

		echo "[INFO] Installing and activating systemd unit files"
		sudo systemctl daemon-reload
		systemctl --user enable --now sync-screenshots.path
		systemctl --user status sync-screenshots.path

		# Symlinking service to workaround forced target directories in Google Photos
		systemctl --user enable --now sync-screenshots-linker.service
		systemctl --user status sync-screenshots-linker.service
		systemctl --user enable --now sync-screenshots-linker.timer
		systemctl --user status sync-screenshots-linker.timer

	elif [[ "${action}" == "run" ]]; then
		echo "[INFO] Syncing screenshots from ${SOURCE_DIR} to ${REMOTE_DIR}, please wait..."
		~/.local/bin/rclone sync -vv -L -P "${SOURCE_DIR}" "${REMOTE_NAME}:${REMOTE_DIR}" \
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
