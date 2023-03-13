#!/bin/bash
# Credit: https://foosel.net/til/how-to-automatically-sync-screenshots-from-the-steamdeck-to-google-drive/

scriptdir=$PWD

rclone_ver="1.61.1"
action=$1
REMOTE_NAME='gphoto'
REMOTE_DIR='album/SteamScreenshots'

# YAY COMPLEX DIRECTORY NUMBERS
# Find current profiles with 'find ~/.steam/steam/ -name "screenshots"'
# Also, you can find this in Steam settings
# Symlink this so the <service>.path is easy and does not change
screenshots_dir="${HOME}/.local/share/Steam/userdata/21885827/760/remote/990080/screenshots"
SOURCE_DIR="${HOME}/.steam_screenshots"


if [[ "${action}" == install ]]; then
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

	echo "[INFO] Symlimking screenshots directory for systemd"
	ln -sfv ${HOME}/.local/share/Steam/userdata/21885827/760/remote/990080/screenshots ${SOURCE_DIR}

	echo "[INFO] Installing and activating systemd unit files"
	cp -v sync-screenshots.path ~/.config/systemd/user/
	cp -v sync-screenshots.service ~/.config/systemd/user/
	sudo systemctl daemon-reload
	systemctl --user enable sync-screenshots.path
	systemctl --user start sync-screenshots.path
	systemctl --user status sync-screenshots.path

elif [[ "${action}" == run ]]; then
	echo "[INFO] Syncing screenshots from ${SOURCE_DIR}, please wait..."
	~/.local/bin/rclone sync -P "${SOURCE_DIR}" "${REMOTE_NAME}:${REMOTE_DIR}"
else
	echo "[ERROR] Unknown action: ${action}. Please use one of: install, run"
	exit 1
fi

