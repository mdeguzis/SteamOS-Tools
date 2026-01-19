#!/bin/bash
# Updates AppImage/Flatpak emulators in one go
# Notes:
#	Where to put files: https://gitlab.com/es-de/emulationstation-de/-/blob/stable-3.0/resources/systems/linux/es_find_rules.xml
#	Emulator files: https://emulation.gametechwiki.com/index.php/Emulator_files

set -e -o pipefail

VERSION="0.8.23"

# Simple script - error handling is done by launcher
CURDIR="${PWD}"
BACKUP_LOC="/tmp/update-emulators-backup"
CONFIG_ROOT="${HOME}/.config/steamos-tools"
APP_LOC="${HOME}/Applications"
CLI=false
DEBUG=false
SKIP_UPDATER=false

# Detect if running in CLI mode
# On macOS, DISPLAY is not set but we still have GUI
if [[ "$(uname)" == "Darwin" ]]; then
	# macOS - check if we have access to zenity
	if ! command -v zenity &> /dev/null; then
		CLI=true
	fi
elif [[ -z ${DISPLAY} ]]; then
	# Linux - check DISPLAY variable
	CLI=true
fi

function show_help() {
	cat <<-HELP_EOF
		===============================================
		SteamOS user software installer/updater
		===============================================

		--all |-a)			Install/update all software
		--core-software | -cs)		Install/update core software (e.g. Decky Loader)
		--update-emulators | -ue)	Install/update emulator software
		--user-flatpaks | -uf)		Install/update user flatpaks
		--user-binaries | -ub)		Install/update user binaries
		 --debug)			Enable debug logging
		--help | -h)			Show this help page


	HELP_EOF
	exit 0
}

curlit() {
	# This function is meantt to grab an archive/file out of a page HTML/CSS dump
	name=$1
	target_folder=$2
	search_url=$3
	exe_match=$4

	if [[ -n ${target_folder} ]]; then
		app_loc="${target_folder}"
	fi

	echo -e "\n[INFO] Updating $name (searching for ${exe_match} on page...)"
	curl -q -v "${search_url}" &>"/tmp/results.txt"
	urls=$(awk -F"[><]" '{for(i=1;i<=NF;i++){if($i ~ /a href=.*\//){print "<" $i ">"}}}' "/tmp/results.txt")
	rm -f "/tmp/results.txt"
	urls_to_parse=()
	for url in $urls; do
		if $(echo "${url}" | grep -q href) && $(echo "${url}" | grep -qE ${exe_match}); then
			dl_url=$(echo "${url}" | sed 's/.*http/http/;s/".*//')

			# which type?
			echo "[INFO] Found download url: '${dl_url}', processing"
			filename=$(basename -- "${dl_url}")
			file_type=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
			echo "[INFO] Filetype found: ${file_type}"

			# Backup
			if ls "${APP_LOC}" | grep -qiE "${name}.*${file_type}"; then
				echo "[INFO] Moving old ${file_type} to .bak in /tmp"
				echo "[INFO] $(find ${APP_LOC} -iname "${name}*${file_type}" -exec mv -v {} ${BACKUP_LOC} \;)"
			fi

			# Handle different file types
			case $file_type in
			"zip")
				curl -sLo "/tmp/${name}.zip" "${dl_url}"
				unzip -o "/tmp/${name}.zip" -d "${APP_LOC}/${name}"
				;;
			"appimage")
				curl -LO --output-dir "${APP_LOC}" "${dl_url}"
				;;

			*)
				echo "I don't know how to process ${file_type}, skipping..."
				return 0
				;;
			esac
		fi
	done

}

update_install_flatpak() {
	# Loop the list and install if update fails (not found)
	# This is more useful so we know exactly what was attempted vs just
	# seeing an error

	name=$1
	ID=$2
	echo -e "\n[INFO] Installing/Updating $name"
	
	if ! flatpak --user update $ID -y; then
		# Install if not found
		if ! flatpak install --user -y --noninteractive $ID; then
			echo "[ERROR] Failed to install Flatpak!"
			return 1
		fi
	fi

	# Adjust common user permission
	flatpak override $ID --filesystem=host --user
	flatpak override $ID --share=network --user
}

update_binary() {
	name=$1
	folder_target=$2
	filename=$3
	URL=$4
	dl_type=$5
	curl_options="-LO --output-dir /tmp"

	echo -e "\n[INFO] Updating binary for $name"

	# The ~/Applications dir is compliant with ES-DE
	if echo "${URL}" | grep -q ".zip"; then
		# Handle direct URL zips
		zip_name=$(basename "${URL}")
		dl_url="${URL}"

	elif echo "${URL}" | grep -q "gitlab.com/api"; then
		echo "[INFO] Fetching latet release from ${URL}"
		latest_release=$(curl -Ls "${URL}" | jq -r '.assets.links[] | select(.name | test('\"$name.*x64.AppImage\"'))')
		artifact_name=$(echo "${latest_release}" | jq -r '.name')
		dl_url=$(echo "${latest_release}" | jq -r '.direct_asset_url')
		# Use -J and --clobber to attach the remote name and overwrite
		curl_options="--clobber -JLO --output-dir /tmp"

	elif echo "${URL}" | grep -qE ".*github.com.*releases.*"; then
		# Handle github release page
		# Try to auto download unless we have a filename regex/name passed
		echo "[INFO] Fetching latet Git release from ${URL}"
		# Prefer app iamge
		# Set download URL
		# Prefer arch-specific first
		# If not /latest, assume pre-release
		if ! echo "${URL}" | grep -q "latest"; then
			collected_urls=$(curl -s "${URL}" | jq -r 'map(select(.prerelease)) | first | .assets[] | .browser_download_url')
		else
			collected_urls=$(curl -s "${URL}" | jq -r '.assets[] | .browser_download_url')
		fi

		for this_url in ${collected_urls}; do
			# Filename / regex to match above all else?
			if [[ -n "${filename}" ]]; then
				if echo "${this_url}" | grep -qE ${filename}; then
					dl_url="${this_url}"
					break
				fi
			else
				# Auto find if no filename given...
				# Prefer AppImage and 64 bit
				if echo "${this_url}" | grep -qE "http.*x.*64.*AppImage$"; then
					dl_url="${this_url}"
					break
				elif echo "${this_url}" | grep -qE "http.*AppImage$"; then
					dl_url="${this_url}"
					break
				elif echo "${this_url}" | grep -qE "http.*${name}-.*linux.*x64.*tar.gz$"; then
					dl_url="${this_url}"
					break
				elif echo "${this_url}" | grep -qE "http.*${name}.*linux.*tar.gz$"; then
					dl_url="${this_url}"
					break
				elif echo "${this_url}" | grep -qE "http.*${name}.*linux.*tar.xz$"; then
					dl_url="${this_url}"
					break
				fi
			fi
		done

		if [[ -z "${dl_url}" ]]; then
			# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28
			echo "[ERROR] Could not get a download url for ${URL}!"
			exit 1
		fi
	else
		dl_url="${URL}"
	fi

	# Backup
	if ls "${APP_LOC}" | grep -qiE "${name}.*${dl_type}" 2>/dev/null; then
		echo "[INFO] Moving old ${dl_type} to /tmp"
		echo "[INFO] $(find ${APP_LOC} -iname "${name}*${dl_type}" -exec mv -v {} ${BACKUP_LOC} \;)"
	fi

	# Download
	echo "[INFO] Downloading ${dl_url}"
	cmd="curl ${curl_options} ${dl_url}"
	eval "${cmd}"

	# Handle download by type
	file_type=$(echo "${dl_type}" | tr '[:upper:]' '[:lower:]')
	if [[ "${file_type}" == "zip" ]]; then
		if [[ -n "${folder_target}" ]]; then
			unzip -o "/tmp/${zip_name}" -d "${APP_LOC}/${folder_target}"
		else
			unzip -o "/tmp/${zip_name}" -d "${APP_LOC}/"
		fi

	elif [[ "${file_type}" == "tar.gz" || "${file_type}" == "tar.xz" ]]; then
		tar_file=$(ls -t /tmp/${name}*${file_type} | head -n 1)
		if [[ -z "${tar_file}" ]]; then
			echo "[ERROR] Could not match tar.gz file!"
			exit 1
		fi

		echo "[INFO] Extracting ${tar_file}"
		if [[ -n "${folder_target}" ]]; then
			mkdir -p "${APP_LOC}/${folder_target}"
			tar -xvf "${tar_file}" -C "${APP_LOC}/${folder_target}"
		else
			tar -xvf "${tar_file}" -C "${APP_LOC}"
		fi

		rm -rf "${tar_file}"

	elif [[ "${file_type}" == "appimage" ]]; then
		app_image=$(ls -ltr /tmp/${name}*AppImage | tail -n 1 | awk '{print $9}')
		if [[ -n "${folder_target}" ]]; then
			mkdir -p "${APP_LOC}/${folder_target}"
			mv -v "${app_image}" "${APP_LOC}/${folder_target}"
		else
			mv -v "${app_image}" "${APP_LOC}"
		fi
	else
		echo "[INFO] Failed to handle download!"
		exit 1
	fi

}

update_steam_emu() {
	name=$1
	folder_target=$2
	exec_name=$3
	steam_location="${HOME}/.steam/steam/steamapps"

	if [[ -n "${folder_target}" ]]; then
		app_dir="${APP_LOC}/${name}"
	else
		app_dir="${APP_LOC}"
	fi
	echo "[INFO] Updating $name"

	if [[ ! -d "${steam_location}" ]]; then
		echo "[ERROR] Steam directory does not exist, skipping installation/update"
	else
		emu_location=$(find "${steam_location}" -name "${exec_name}" || true)
		emu_dir=$(dirname "${emu_location}")
		if [[ -z "${emu_location}" ]]; then
			echo "[ERROR] Could not find Steam app location for ${name} with exec name ${exec_name} ! Skipping..."
			return
		fi
		mkdir -p "${app_dir}"
		cp -r ${emu_dir}/* "${app_dir}"
	fi
}

update_user_binaries() {
	# Check if user wants to return to main menu before starting
	if [[ "$RETURN_TO_MAIN_MENU" == "true" ]]; then
		$DEBUG && echo "[DEBUG] RETURN_TO_MAIN_MENU detected in update_user_binaries, returning to main menu"
		return 1
	fi

	######################################################################
	# Binaries
	# Args: name, folder target, filename to match (regex), url, type
	######################################################################
	echo -e "\n[INFO] Updating user binaries"
	sleep 2

	####################################
	# Wine / Proton
	####################################

	echo "Skipping, none for now"
	# Use wine cellar
	#update_binary "wine-staging_ge-proton" "Proton" "" "https://api.github.com/repos/mmtrt/WINE_AppImage/releases/latest" "AppImage"	
	####################################
	# Gamejolt
	####################################

	# Check if user wants to return to main menu after completion
	if [[ "$RETURN_TO_MAIN_MENU" == "true" ]]; then
		$DEBUG && echo "[DEBUG] RETURN_TO_MAIN_MENU detected after update_user_binaries completion"
		return 1
	fi

	return 0
}

update_core_software() {
	# Check if user wants to return to main menu before starting
	if [[ "$RETURN_TO_MAIN_MENU" == "true" ]]; then
		$DEBUG && echo "[DEBUG] RETURN_TO_MAIN_MENU detected in update_core_software, returning to main menu"
		return 1
	fi

	# Decky Loader only if it does not exist
	#if [[ ! -f "${HOME}/homebrew/services/PluginLoader" ]]; then
	#	echo "[INFO] Installing Decky Loader"
	#	curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_prerelease.sh | sh
	#else
	#	echo "[INFO] Decky Loader [OK]"
	#fi

	echo -e "\n[INFO] Copying configs\n"

	# need to run once to get configs placed
	if ! update_install_flatpak "Ludusavi" "com.github.mtkennerly.ludusavi"; then
		$DEBUG && echo "[DEBUG] Ludusavi installation/update failed or was cancelled"
		return 1
	fi
	flatpak run com.github.mtkennerly.ludusavi --version

	echo "[INFO] ludusavi"
	# Copy config from source if it exists, otherwise create basic config
	if [[ -f "${CURDIR}/cfgs/ludusavi/config.yaml" ]]; then
		cp -v "${CURDIR}/cfgs/ludusavi/config.yaml" "${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi/config.yaml"
		sed -i "s|HOME_PATH|${HOME}|g" "${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi/config.yaml"
	else
		echo "[INFO] Creating basic Ludusavi config"
		mkdir -p "${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi"
		cat > "${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi/config.yaml" << EOF
# Ludusavi configuration
# Generated by SteamOS Tools updater
backups:
  directory: "${HOME}/.local/share/ludusavi/backups"
  format: zip
  compression: standard
  include:
    - saves
    - settings
    - profiles
    - mods
    - screenshots
    - replays
    - saves
EOF
	fi

	#
	# systemd units (user mode)
	#

	# ludusavi
	# https://github.com/mtkennerly/ludusavi/blob/master/docs/help/backup-automation.md
	echo -e "\n[INFO] Installing systemd user service for ludusavi (backups)"
	# Copy systemd files from source if they exist, otherwise create basic ones
	if [[ -f "${CURDIR}/cfgs/systemd/ludusavi-backup.service" ]]; then
		mkdir -p "${HOME}/.config/systemd/user"
		cp -v "${CURDIR}/cfgs/systemd/ludusavi-backup.service" "${HOME}/.config/systemd/user/ludusavi-backup.service"
	else
		echo "[INFO] Creating basic ludusavi-backup.service"
		mkdir -p "${HOME}/.config/systemd/user"
		cat > "${HOME}/.config/systemd/user/ludusavi-backup.service" << EOF
[Unit]
Description=Ludusavi Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak run com.github.mtkennerly.ludusavi backup
EOF
	fi
	
	if [[ -f "${CURDIR}/cfgs/systemd/ludusavi-backup.timer" ]]; then
		cp -v "${CURDIR}/cfgs/systemd/ludusavi-backup.timer" "${HOME}/.config/systemd/user/ludusavi-backup.timer"
	else
		echo "[INFO] Creating basic ludusavi-backup.timer"
		cat > "${HOME}/.config/systemd/user/ludusavi-backup.timer" << EOF
[Unit]
Description=Run Ludusavi Backup Daily
Requires=ludusavi-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
	fi
	
	systemctl --user enable ludusavi-backup.timer
	systemctl --user restart ludusavi-backup.timer

	# Check if user wants to return to main menu after completion
	if [[ "$RETURN_TO_MAIN_MENU" == "true" ]]; then
		$DEBUG && echo "[DEBUG] RETURN_TO_MAIN_MENU detected after update_core_software completion"
		return 1
	fi

	return 0
}

update_emulator_software() {
	# Check if user wants to return to main menu before starting
	if [[ "$RETURN_TO_MAIN_MENU" == "true" ]]; then
		$DEBUG && echo "[DEBUG] RETURN_TO_MAIN_MENU detected in update_emulator_software, returning to main menu"
		return 1
	fi

	######################################################################
	# Flatpak
	# Args: general name, flatpak package name
	######################################################################
	echo -e "\n[INFO] Updating emulators (Flatpaks)"
	
	# Create array of flatpak updates for progress tracking
	flatpak_updates=(
		"dolphin-emu:org.DolphinEmu.dolphin-emu"
		"DOSBox-Staging:io.github.dosbox-staging"
		"DuckStation:org.duckstation.DuckStation"
		"Flycast:org.flycast.Flycast"
		"MAME:org.mamedev.MAME"
		"melonDS:net.kuribo64.melonDS"
		"mGBA:io.mgba.mGBA"
		"Mupen64Plus (GUI):com.github.Rosalie241.RMG"
		"Pegasus:org.pegasus_frontend.Pegasus"
		"PPSSPP:org.ppsspp.PPSSPP"
		"PrimeHack:io.github.shiiion.primehack"
		"RetroArch:org.libretro.RetroArch"
		"RMG:com.github.Rosalie241.RMG"
		"RPCS3:net.rpcs3.RPCS3"
		"shadPS4:net.shadps4.shadPS4"
		"ScummVM:org.scummvm.ScummVM"
		"VICE:net.sf.VICE"
		"Xemu-Emu:app.xemu.xemu"
	)
	
	# Update flatpaks with progress tracking
	for update in "${flatpak_updates[@]}"; do
		name="${update%%:*}"
		id="${update#*:}"
		if ! update_install_flatpak "$name" "$id"; then
			$DEBUG && echo "[DEBUG] $name update failed or was cancelled"
			return 1
		fi
	done

	if [[ -d "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" ]]; then
		echo -e "\n[INFO] These cores are installed from the RetroArch flatpak:"
		cores_list=$(ls "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" | column -c 150)
		echo "$cores_list"
	fi

	######################################################################
	# Binaries
	# Args: name, folder target, filename to match (regex), url, type
	######################################################################
	echo -e "\n[INFO] Updating emulators (binaries)"

	####################################
	# Single file binaries
	####################################
	update_binary "dolphin-emu-triforce" "" "" "https://github.com/mdeguzis/SteamOS-Tools/raw/master/AppImage/dolphin-emu-triforce.AppImage" "AppImage"

	####################################
	# ZIPs
	####################################
	update_binary "xenia_master" "xenia" "" "https://github.com/xenia-project/release-builds-windows/releases/latest/download/xenia_master.zip" "zip"
	update_binary "xenia_canary" "xenia-canary" "" "https://api.github.com/repos/xenia-canary/xenia-canary-releases/releases/latest" "tar.xz"
	# Note that the Panda3DS AppImage name is oddly named: "Alber-x86_64.AppImage"
	update_binary "Panda3DS" "" "" "https://github.com/wheremyfoodat/Panda3DS/releases/latest/download/Linux-SDL.zip" "zip"

	####################################
	# From GitHub release pages
	####################################
	# Careful not to get rate exceeded here...
	update_binary "ES-DE" "" "" "https://gitlab.com/api/v4/projects/18817634/releases/permalink/latest" "AppImage"
	update_binary "Steam-ROM-Manager" "" "" "https://api.github.com/repos/SteamGridDB/steam-rom-manager/releases/latest" "AppImage"
	# RIP Ryujinx
	#update_binary "ryujinx" "" "" "https://api.github.com/repos/Ryujinx/release-channel-master/releases/latest" "tar.gz"
	update_binary "pcsx2" "" "" "https://api.github.com/repos/PCSX2/pcsx2/releases" "AppImage"
	# No Cemu latest tag has a Linux AppImage, must use use pre-releases
	update_binary "Cemu" "" "" "https://api.github.com/repos/cemu-project/Cemu/releases" "AppImage"
	update_binary "Vita3K" "" "" "https://api.github.com/repos/Vita3K/Vita3K/releases/latest" "AppImage"

	# From web scrape
	curlit "rpcs3" "" "https://rpcs3.net/download" ".*rpcs3.*_linux64.AppImage"
	curlit "BigPEmu" "" "https://www.richwhitehouse.com/jaguar/index.php?content=download" ".*BigPEmu.*[0-9].zip"

	####################################
	# Steam
	# Args: name, folder, exec name
	####################################

	# Unsed for now
	## https://steamdb.info/app/1147940/
	#update_steam_emu "3dSen" "3dSen" "3dSen.exe"

	####################################
	# Fixes
	####################################
	echo -e "\n[INFO] Applying compatibility fixes"

	# If we are still making use of EmuDeck for anything, it imposes an imcorrect name "pcsx2-Qt"
	# https://github.com/dragoonDorise/EmuDeck/blob/main/tools/launchers/pcsx2-qt.sh#L4
	# Releases are named "pcsx2-[VERSION]-linux-appimage-x64-Qt.AppImage" on https://github.com/PCSX2/pcsx2/releases
	find "${HOME}/Applications/" -name "pcsx2*AppImage" -exec ln -sfv {} "${HOME}/Applications/pcsx2-Qt.AppImage" \;

	return 0
}

update_user_flatpaks() {
	# Tools
	update_install_flatpak "Protontricks" "com.github.Matoking.protontricks"
	update_install_flatpak "Heroic Games Launcher" "com.heroicgameslauncher.hgl"
	update_install_flatpak "Chrome" "com.google.Chrome"
	update_install_flatpak "Limo" "io.github.limo_app.limo"

	# Update the rest of the user's Flatpaks
	flatpak --user --noninteractive upgrade
}

show_installed_flatpaks() {
	$DEBUG && echo "[DEBUG] Showing installed Flatpaks"
	while true; do
		installed_list=$(flatpak list --app --columns=application,name,description,version 2>/dev/null)
		if [[ -z "${installed_list}" ]]; then
			zenity --info \
				--title="No Apps Installed" \
				--text="No Flatpak applications are currently installed." \
				--width=400 \
				--height=150
			return 0
		fi
		installed_count=$(echo "${installed_list}" | wc -l)
		list_args=()
		while IFS=$'\t' read -r app_id name description _version; do
			if [[ ${#description} -gt 60 ]]; then
				description="${description:0:57}..."
			fi
			list_args+=("${app_id}" "${name}" "${description}")
		done < <(echo "${installed_list}")

		selected_app=""
		# Show the list, no extra buttons, with a note
		zen_out=$(zenity --list \
			--title="Installed Flatpaks - ${installed_count} apps" \
			--text="Double click an item for available actions." \
			--column="App ID" \
			--column="Name" \
			--column="Description" \
			"${list_args[@]}" \
			--width=1000 \
			--height=700 \
			--print-column=1 \
			--extra-button="Exit")
		sleep 2
		button_pressed=$?
		$DEBUG && echo "[DEBUG] Zenity returned: button_pressed=$button_pressed, zen_out='$zen_out'"
		if [[ "$zen_out" == "Exit" ]]; then
			$DEBUG && echo "[DEBUG] User chose Exit from app list. Exiting."
			handle_zenity_cancel
			return 1
		fi
		if [[ $button_pressed -eq 1 || -z "$zen_out" ]]; then
			$DEBUG && echo "[DEBUG] User cancelled the dialog or no selection. Returning to main menu."
			return 0  # Return to main menu
		fi
		selected_app="$zen_out"
		$DEBUG && echo "[DEBUG] Row double-clicked or OK: selected_app='$selected_app'"
		# Show action dialog
		action=$(zenity --list \
			--title="App Actions" \
			--text="Choose an action for <b>${selected_app}</b>:" \
			--column="Action" "Info" "Update" "Uninstall" "Cancel" "Exit" \
			--width=400 --height=500)
		sleep 2
		$DEBUG && echo "[DEBUG] Action dialog: action='$action'"
		if [[ "$action" == "Exit" ]]; then
			$DEBUG && echo "[DEBUG] User chose Exit from action dialog. Exiting."
			handle_zenity_cancel
			return 1
		fi
		if [[ "$action" == "Cancel" || -z "$action" ]]; then
			$DEBUG && echo "[DEBUG] User cancelled action dialog."
			continue
		fi
		app_row=$(echo "${installed_list}" | grep -F "${selected_app}")
		IFS=$'\t' read -r _app_id app_name app_description app_version <<< "$app_row"
		if [[ "$action" == "Info" ]]; then
			$DEBUG && echo "[DEBUG] Info action for: ${selected_app}"
			info_text=$(get_flathub_app_info "$selected_app" "$app_name" "$app_version" "$app_description")
			zenity --info \
				--title="App Info: ${app_name}" \
				--text="${info_text}" \
				--width=700 \
				--height=600 2>/dev/null || true
			continue
		elif [[ "$action" == "Update" ]]; then
			$DEBUG && echo "[DEBUG] Update action for: ${selected_app}"
			(
				echo "[ACTION] Running: flatpak --user update '${selected_app}' -y"
				flatpak --user update "${selected_app}" -y 2>&1
				exit_code=${PIPESTATUS[0]}
				if [[ ${exit_code} -eq 0 ]]; then
					echo "[INFO] Update complete!"
				else
					echo "[ERROR] Update failed!"
				fi
				exit ${exit_code}
			 ) | zenity --text-info \
				--title="Update Output: ${app_name}" \
				--width=900 --height=600 \
				--ok-label="OK" \
				 --extra-button="Exit"
			log_button=$?
			if [[ "$log_button" == "Exit" ]]; then
				handle_zenity_cancel
			fi
			continue
		elif [[ "$action" == "Uninstall" ]]; then
			$DEBUG && echo "[DEBUG] Uninstall action for: ${selected_app}"
			zenity --question \
				--title="Confirm Uninstall" \
				--text="Are you sure you want to uninstall <b>${app_name}</b>?" \
				--width=400 \
				--height=150 \
				--ok-label="Uninstall" \
				--cancel-label="Back"
			if [[ $? -eq 0 ]]; then
				(
					echo "[ACTION] Running: flatpak --user uninstall '${selected_app}' -y"
					flatpak --user uninstall "${selected_app}" -y 2>&1
					exit_code=${PIPESTATUS[0]}
					if [[ ${exit_code} -eq 0 ]]; then
						echo "[INFO] Uninstall complete!"
					else
						echo "[ERROR] Uninstall failed!"
					fi
					exit ${exit_code}
				) | zenity --text-info \
					--title="Uninstall Output: ${app_name}" \
					--width=900 --height=600 \
					--ok-label="OK" \
					--extra-button="Exit"
				uninstall_log_button=$?
				if [[ "$uninstall_log_button" == "Exit" ]]; then
					handle_zenity_cancel
				fi
				# Refresh installed list after uninstall
				installed_flatpaks=$(flatpak list --app --columns=application 2>/dev/null || echo "")
				continue
			fi
		fi
	done
}

search_and_install_flathub() {
	$DEBUG && echo "[DEBUG] Entered search_and_install_flathub screen"
	echo -e "\n[INFO] Flathub app search and install"
	
	# Get list of installed flatpaks once
	installed_flatpaks=$(flatpak list --app --columns=application 2>/dev/null || echo "")
	
	while true; do
		# Get search query from user
		search_query=$(zenity --entry \
			--title="Search Flathub" \
			--text="Enter app name to search on Flathub:" \
			--width=400 \
			--height=150)
		$DEBUG && echo "[DEBUG] User search query: $search_query"
		if [[ $? -ne 0 || -z "${search_query}" ]]; then
			# User cancelled or entered empty query
			$DEBUG && echo "[DEBUG] User cancelled search, returning to main menu"
			return 1
		fi
		
		echo "[INFO] Searching Flathub for: ${search_query}"
		
		# Show progress dialog while searching
		(
			echo "10" ; echo "# Connecting to Flathub API..."
			sleep 0.5
			echo "50" ; echo "# Searching for '${search_query}'..."
			sleep 0.5
			echo "100" ; echo "# Processing results..."
		) | zenity --progress \
			--title="Searching Flathub" \
			--text="Searching..." \
			--percentage=0 \
			--auto-close \
			--no-cancel \
			--width=400 \
			--height=150 2>/dev/null
		
		# Search Flathub API (requires POST with JSON)
		search_results=$(curl -s -X POST "https://flathub.org/api/v2/search" \
			-H "Content-Type: application/json" \
			-d "{\"query\":\"${search_query}\"}")
		
		# Check if results are valid
		if ! echo "${search_results}" | jq -e '.hits' >/dev/null 2>&1; then
			zenity --error \
				--title="Search Error" \
				--text="Failed to search Flathub. Please check your internet connection." \
				--width=400 \
				--height=150
			continue
		fi
		
		# Parse results and create zenity list
		results_count=$(echo "${search_results}" | jq '.hits | length')
		
		if [[ ${results_count} -eq 0 ]]; then
			zenity --info \
				--title="No Results" \
				--text="No apps found matching '${search_query}'" \
				--width=400 \
				--height=150
			continue
		fi
		
		echo "[INFO] Found ${results_count} results"
		
		# Build zenity list arguments with status column
		list_args=()
		while IFS=$'\t' read -r app_id name summary; do
			# Truncate summary if too long
			if [[ ${#summary} -gt 70 ]]; then
				summary="${summary:0:67}..."
			fi
			
			# Check installation status
			if echo "${installed_flatpaks}" | grep -q "^${app_id}$"; then
				status="✓ Installed"
			else
				status="Not Installed"
			fi
			
			list_args+=("${app_id}" "${name}" "${summary}" "${status}")
		done < <(echo "${search_results}" | jq -r '.hits[] | [.app_id, .name, .summary] | @tsv')
		
		# Show results in zenity list with status
		selected_app=$(zenity --list \
			--title="Flathub Search Results - ${results_count} apps found" \
			--text="Select an app (searched for: '${search_query}'):" \
			--column="App ID" \
			--column="Name" \
			--column="Description" \
			--column="Status" \
			"${list_args[@]}" \
			--width=1100 \
			--height=700 \
			--print-column=1)
		$DEBUG && echo "[DEBUG] User selected app: $selected_app"
		if [[ $? -ne 0 || -z "${selected_app}" ]]; then
			# User cancelled selection, return to main menu
			$DEBUG && echo "[DEBUG] User cancelled selection, returning to main menu"
			return 1
		fi
		# Get app details
		app_name=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .name')
		app_summary=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .summary')
		app_version=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .version // "N/A"')
		app_description=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .description // .summary // "N/A"')
		# Show rich info before install
		info_text=$(get_flathub_app_info "$selected_app" "$app_name" "$app_version" "$app_summary")
		# Remove info dialog, only show confirmation
		zenity --question \
			--title="Confirm Installation" \
			--text="${info_text}\n\nThe app will be installed with user-level permissions." \
			--width=700 \
			--height=600 \
			--ok-label="Install" \
			--cancel-label="Back"
		install_confirmed=$?
		$DEBUG && echo "[DEBUG] User install_confirmed: $install_confirmed (0=yes, 1=no)"
		if [[ $install_confirmed -ne 0 ]]; then
			# User clicked No/Cancel, return to main menu immediately
			$DEBUG && echo "[DEBUG] User cancelled install, returning to main menu"
			return 1
		fi
		# Install the app with live output dialog
		(
			echo "[ACTION] Running: flatpak install --user -y flathub '${selected_app}'"
			flatpak install --user -y flathub "${selected_app}" 2>&1
			exit_code=${PIPESTATUS[0]}
			if [[ ${exit_code} -eq 0 ]]; then
				echo "[INFO] Installation complete!"
			else
				echo "[ERROR] Installation failed!"
			fi
			exit ${exit_code}
		) | zenity --text-info \
			--title="Install Output: ${app_name}" \
			--width=900 --height=600 \
			--ok-label="OK" \
			--extra-button="Exit"
		install_log_button=$?
		if [[ "$install_log_button" == "Exit" ]]; then
			handle_zenity_cancel
			return 1
		fi
		# Refresh installed list after install
		installed_flatpaks=$(flatpak list --app --columns=application 2>/dev/null || echo "")
		# After install, return to main menu (not to search text)
		return 1
		
		# Ask if user wants to search for more apps
		zenity --question \
			--title="Install More Apps?" \
			--text="Do you want to search for and install another app?" \
			--width=400 \
			--height=150
		sleep 2
		more_apps=$?
		$DEBUG && echo "[DEBUG] User more_apps: $more_apps (0=yes, 1=no)"
		if [[ $more_apps -ne 0 ]]; then
			$DEBUG && echo "[DEBUG] User chose not to install more apps, returning to main menu"
			return 1
		fi
	done
}

# Helper: convert HTML to plain text for zenity dialogs
html_to_text() {
    local html="$1"
    # Replace <li> with bullet points
    html=$(echo "$html" | sed -e 's/<[\/]\?b>//g' \
                              -e 's/<[\/]\?ul>//g' \
                              -e 's/<li>/* /g' \
                              -e 's/<\/li>/\n/g' \
                              -e 's/<p>/\n/g' \
                              -e 's/<\/p>/\n/g' \
                              -e 's/<br[\/]\?>/\n/g' \
                              -e 's/<[\/]\?[a-zA-Z0-9]*>//g')
    # Remove any remaining tags
    html=$(echo "$html" | sed -e 's/<[^>]*>//g')
    # Collapse multiple newlines
    html=$(echo "$html" | tr -s '\n')
    echo "$html"
}

# Helper: get rich app info from Flathub API
get_flathub_app_info() {
    local app_id="$1"
    local app_name="$2"
    local app_version="$3"
    local app_summary="$4"
    local flathub_data app_developer app_license app_homepage app_categories app_description app_installs info_text
    flathub_data=$(curl -s "https://flathub.org/api/v2/appstream/${app_id}" 2>/dev/null || echo "{}")
    app_developer=$(echo "${flathub_data}" | jq -r '.developer_name // "N/A"' 2>/dev/null || echo "N/A")
    app_license=$(echo "${flathub_data}" | jq -r '.project_license // "N/A"' 2>/dev/null || echo "N/A")
    app_homepage=$(echo "${flathub_data}" | jq -r '.urls.homepage // "N/A"' 2>/dev/null || echo "N/A")
    app_categories=$(echo "${flathub_data}" | jq -r '.main_categories[]?, .sub_categories[]? // empty' 2>/dev/null | tr '\n' ', ' | sed 's/,$//' 2>/dev/null || echo "N/A")
    app_description=$(echo "${flathub_data}" | jq -r '.description // "N/A"' 2>/dev/null || echo "N/A")
    app_installs=$(echo "${flathub_data}" | jq -r '.installs_last_month // "N/A"' 2>/dev/null || echo "N/A")
    # Convert HTML to plain text for zenity, and trim excessive whitespace
    app_description_plain=$(html_to_text "${app_description}" | awk 'NF' | sed '/^[[:space:]]*$/d')
    # Compose info text with minimal spacing
    info_text="Name: ${app_name}\nApp ID: ${app_id}\nSummary: ${app_summary}\nDescription: ${app_description_plain}\nDeveloper: ${app_developer}\nLicense: ${app_license}\nCategories: ${app_categories}\nHomepage: ${app_homepage}\nInstalls last month: ${app_installs}"
    echo "$info_text"
}

######################################################################
# CLI-args
######################################################################
while :; do
	case $1 in
	--all |-a)
		ALL=true
		;;

	--core-software | -cs)
		CORE_SOFTWARE=true
		;;

	--update-emulators | -ue)
		UPDATE_EMULATORS=true
		;;

	--user-flatpaks | -uf)
		USER_FLATPAKS=true
		;;

	--user-binaries | -ub)
		USER_BINARIES=true
		;;

	--debug)
		DEBUG=true
		;;

	--skip-updater)
		SKIP_UPDATER=true
		;;

	--help | -h)
		show_help
		;;

	--)
		# End of all options.
		shift
		break
		;;

	-?*)
		printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;

	*)
		# Default case: If no more options then break out of the loop.
		break
		;;

	esac

	# shift args
	shift
done
echo

# Function to fetch latest version from remote (GitHub raw or repo URL)
get_latest_version() {
	# Example: fetch from GitHub raw file
	LATEST_URL="https://raw.githubusercontent.com/mdeguzis/SteamOS-Tools/master/utilities/update-software/update-software.sh"
	$DEBUG && echo "[DEBUG] Fetching latest version from $LATEST_URL"
	latest_version=$(curl -fsSL "$LATEST_URL" | grep '^VERSION="' | head -n1 | cut -d'"' -f2)
	if [[ -z "$latest_version" ]]; then
		$DEBUG && echo "[DEBUG] Could not fetch latest version, defaulting to local version"
		latest_version="$VERSION"
	fi
	echo "$latest_version"
}

# Compare two version strings (returns 0 if v1 < v2)
version_lt() {
	[ "$1" = "$2" ] && return 1
	sort -V <(echo -e "$1\n$2") | head -n1 | grep -qx "$1"
}

main() {
	$DEBUG && echo "[DEBUG] Entered main menu screen"
	
	
	# Set up global signal handlers for clean cancellation
	trap 'handle_zenity_cancel' SIGINT SIGTERM
	
	######################################################################
	# Initialization - run once at startup
	######################################################################
	
	# Set Zenity margins based on screen resolution
	if ! ${CLI}; then
		# Height in px of the top system bar
		TOP_MARGIN="${TOP_MARGIN:=27}"
		# Height in px of all horizontal borders
		RIGHT_MARGIN="${RIGHT_MARGIN:=10}"

		# Get width and height of video out
		if [[ "$(uname)" == "Darwin" ]]; then
			# macOS - use system_profiler
			SCREEN_WIDTH=$(system_profiler SPDisplaysDataType | grep Resolution | awk '{print $2}' | head -n1)
			SCREEN_HEIGHT=$(system_profiler SPDisplaysDataType | grep Resolution | awk '{print $4}' | head -n1)
			# Default to reasonable values if detection fails
			SCREEN_WIDTH=${SCREEN_WIDTH:-1920}
			SCREEN_HEIGHT=${SCREEN_HEIGHT:-1080}
		else
			# Linux - xwininfo is built into most OS distributions
			SCREEN_WIDTH=$(xwininfo -root | awk '$1=="Width:" {print $2}')
			SCREEN_HEIGHT=$(xwininfo -root | awk '$1=="Height:" {print $2}')
		fi
		
		W=$((${SCREEN_WIDTH} / 2 - ${RIGHT_MARGIN}))
		H=$((${SCREEN_HEIGHT} / 2 - ${TOP_MARGIN}))

		echo "[INFO] Screen dimensions detected:"
		echo "[INFO] Width: ${SCREEN_WIDTH}"
		echo "[INFO] Height: ${SCREEN_HEIGHT}"
	fi

	# Pre-reqs - run once at startup
	echo "[INFO] Updater version: ${VERSION}"

	mkdir -p "${APP_LOC}"
	mkdir -p "${BACKUP_LOC}"

	# Check for rate exceeded
	echo "[INFO] Testing Git API"
	sleep 2
	git_test=$(curl -s "https://api.github.com")
	if echo "${git_test}" | grep -q "exceeded"; then
		echo "${git_test}"
		exit 1
	else
		echo "[INFO] Git API test: [OK]"
	fi

	echo "[INFO] Ensuring user-scope Flathub remote exists"
	flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

	######################################################################
	# Main menu loop - handles cancellation and restarts
	######################################################################
	while true; do
			if ! ${CLI}; then
				 ask=$(zenity --list \
		            --title="Software Updater (Version: ${VERSION})" \
		            --column=0 \
		            "Update All Software" \
		            "Update Core Software" \
		            "Update Emulators and Associated Software" \
		            "Update User Flatpaks" \
		            "Update User Binaries" \
		            "Search and Install from Flathub" \
		            "Show Installed Flatpaks" \
		            --cancel-label="Exit" \
		            --width ${W} \
		            --height ${H} \
		            --hide-header)
				$DEBUG && echo "[DEBUG] User main menu selection: $ask"
				if [[ $? -ne 0 ]]; then
					$DEBUG && echo "[DEBUG] User exited from main menu"
					echo "[INFO] Exiting..."
					exit 0
				fi

				echo "[INFO] Choice entered: '${ask}'"
			fi

			# Capture exit code to handle zenity cancellation
			if [[ "${ask}" == "Update All Software" || ${ALL} ]]; then
				echo "Starting comprehensive software update..."
				update_core_software
				update_emulator_software
				update_user_binaries
				update_user_flatpaks
			else
				if [[ "${ask}" == "Update Emulators and Associated Software" || ${UPDATE_EMULATORS} ]]; then
					echo "Starting emulator software update..."
					update_emulator_software
				elif [[ "${ask}" == "Update Core Software" || ${CORE_SOFTWARE} ]]; then
					echo "Starting core software update..."
					update_core_software
				elif [[ "${ask}" == "Update User Flatpaks" || ${USER_FLATPAKS} ]]; then
					echo "Starting user flatpak update..."
					update_user_flatpaks
				elif [[ "${ask}" == "Update User Binaries" || ${USER_BINARIES} ]]; then
					echo "Starting user binary update..."
					update_user_binaries
				elif [[ "${ask}" == "Search and Install from Flathub" ]]; then
					search_and_install_flathub || continue
				elif [[ "${ask}" == "Show Installed Flatpaks" ]]; then
					show_installed_flatpaks
				fi
			fi

			# If we reach here, the operation completed successfully
			# Pause a bit when running GameMode
			if ! ${CLI}; then
				sleep 2
				exit 0
			fi
		done
}

# Run main (logging is handled by launcher)
main
echo "[INFO] Updater completed successfully"
