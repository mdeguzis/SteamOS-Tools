#!/bin/bash
# Updates AppImage/Flatpak emulators in one go
# Notes:
#	Where to put files: https://gitlab.com/es-de/emulationstation-de/-/blob/stable-3.0/resources/systems/linux/es_find_rules.xml
#	Emulator files: https://emulation.gametechwiki.com/index.php/Emulator_files

set -e -o pipefail

VERSION="0.8.22"

# Simple script - error handling is done by launcher
CURDIR="${PWD}"
BACKUP_LOC="/tmp/update-emulators-backup"
CONFIG_ROOT="${HOME}/.config/steamos-tools"
APP_LOC="${HOME}/Applications"
CLI=false

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
		flatpak install --user -y --noninteractive $ID
		if [[ $? -ne 0 ]]; then
			echo "[ERROR] Failed to install Flatpak!"
			exit 1
		fi
	#else
	#	flatpak --user info $ID | grep Version | sed 's/\ //g'
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

}

update_core_software() {
	# Decky Loader only if it does not exist
	if [[ ! -f "${HOME}/homebrew/services/PluginLoader" ]]; then
		echo "[INFO] Installing Decky Loader"
		curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_prerelease.sh | sh
	else
		echo "[INFO] Decky Loader [OK]"
	fi

	echo -e "\n[INFO] Copying configs\n"

	# need to run once to get configs placed
	update_install_flatpak "Ludusavi" "com.github.mtkennerly.ludusavi"
	flatpak run com.github.mtkennerly.ludusavi --version

	echo "[INFO] ludusavi"
	cp -v ${CONFIG_ROOT}/ludusavi/config.yaml ${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi/config.yaml
	sed -i "s|HOME_PATH|${HOME}|g" ${HOME}/.var/app/com.github.mtkennerly.ludusavi/config/ludusavi/config.yaml

	#
	# systemd units (user mode)
	#

	# ludusavi
	# https://github.com/mtkennerly/ludusavi/blob/master/docs/help/backup-automation.md
	echo -e "\n[INFO] Installing systemd user service for ludusavi (backups)"
	cp -v "${CONFIG_ROOT}/systemd/ludusavi-backup.service" "${HOME}/.config/systemd/user/ludusavi-backup.service"
	cp -v "${CONFIG_ROOT}/systemd/ludusavi-backup.timer" "${HOME}/.config/systemd/user/ludusavi-backup.timer"
	systemctl --user enable ludusavi-backup.timer
	systemctl --user restart ludusavi-backup.timer

}

update_emulator_software() {

	######################################################################
	# Flatpak
	# Args: general name, flatpak package name
	######################################################################
	echo -e "\n[INFO] Updating emulators (Flatpaks)\n"
	sleep 2
	# RIP Citra
	# update_install_flatpak "Citra" "org.citra_emu.citra"
	update_install_flatpak "dolphin-emu" "org.DolphinEmu.dolphin-emu"
	update_install_flatpak "DOSBox-Staging" "io.github.dosbox-staging"
	update_install_flatpak "DuckStation" "org.duckstation.DuckStation"
	update_install_flatpak "Flycast" "org.flycast.Flycast"
	update_install_flatpak "MAME" "org.mamedev.MAME"
	update_install_flatpak "melonDS" "net.kuribo64.melonDS"
	update_install_flatpak "mGBA" "io.mgba.mGBA"
	update_install_flatpak "Mupen64Plus (GUI)" "com.github.Rosalie241.RMG"
	update_install_flatpak "Pegasus" "org.pegasus_frontend.Pegasus"
	update_install_flatpak "PPSSPP" "org.ppsspp.PPSSPP"
	update_install_flatpak "PrimeHack" "io.github.shiiion.primehack"
	update_install_flatpak "RetroArch" "org.libretro.RetroArch"
	update_install_flatpak "RMG" "com.github.Rosalie241.RMG"
	update_install_flatpak "RPCS3" "net.rpcs3.RPCS3"
	# RIP Ryujinx
	#update_install_flatpak "Ryujinx" "org.ryujinx.Ryujinx"
	update_install_flatpak "shadPS4" "net.shadps4.shadPS4"
	update_install_flatpak "ScummVM" "org.scummvm.ScummVM"
	update_install_flatpak "VICE" "net.sf.VICE"
	update_install_flatpak "Xemu-Emu" "app.xemu.xemu"

	if [[ -d "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" ]]; then
		echo -e "\n[INFO] These cores are installed from the Retorach flatpak: "
		ls "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" | column -c 150
	fi

	######################################################################
	# Binaries
	# Args: name, folder target, filename to match (regex), url, type
	######################################################################
	echo -e "\n[INFO] Updating emulators (binaries)\n"
	sleep 2

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
	#echo -e "\n[INFO] Symlinking any emulators from Steam"
	#sleep 2
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
	echo -e "\n[INFO] Showing installed Flatpaks"
	
	# Get list of installed flatpaks with names
	installed_list=$(flatpak list --app --columns=application,name,description,version 2>/dev/null)
	
	if [[ -z "${installed_list}" ]]; then
		zenity --info \
			--title="No Apps Installed" \
			--text="No Flatpak applications are currently installed." \
			--width=400 \
			--height=150
		return 0
	fi
	
	# Count installed apps
	installed_count=$(echo "${installed_list}" | wc -l)
	
	# Build zenity list arguments
	list_args=()
	while IFS=$'\t' read -r app_id name description version; do
		# Truncate description if too long
		if [[ ${#description} -gt 60 ]]; then
			description="${description:0:57}..."
		fi
		list_args+=("${app_id}" "${name}" "${description}")
	done < <(echo "${installed_list}")
	
	# Show installed apps in zenity list with action buttons
	# Button order: Info, Update, Uninstall (left to right after OK/Cancel)
	selected_app=$(zenity --list \
		--title="Installed Flatpaks - ${installed_count} apps" \
		--text="Select an app and choose an action:" \
		--column="App ID" \
		--column="Name" \
		--column="Description" \
		"${list_args[@]}" \
		--extra-button="Info" \
		--extra-button="Update" \
		--extra-button="Uninstall" \
		--width=750 \
		--height=450 \
		--print-column=1)
	
	button_pressed=$?
	
	# Check which button was pressed or if cancelled
	# 0 = OK, 1 = Cancel/Escape, 5 = Extra button 1 (Info), 6 = Extra button 2 (Update), 7 = Extra button 3 (Uninstall)
	if [[ ${button_pressed} -eq 1 || ${button_pressed} -eq 0 ]]; then
		# User cancelled, pressed OK, or no selection - return to main menu
		return 0
	fi
	
	# Ensure an app was selected
	if [[ -z "${selected_app}" ]]; then
		return 0
	fi
	
	# Get app details from the list
	app_name=$(echo "${installed_list}" | grep "^${selected_app}" | cut -f2)
	app_description=$(echo "${installed_list}" | grep "^${selected_app}" | cut -f3)
	app_version=$(echo "${installed_list}" | grep "^${selected_app}" | cut -f4)
	
	if [[ ${button_pressed} -eq 5 ]]; then
		# Info button pressed - run in isolated subshell to prevent error propagation
		(
			# Completely disable error handling in subshell
			set +eE +o pipefail
			trap - ERR
			
			# Get full app info from flatpak (local)
			full_info=$(flatpak info "${selected_app}" 2>&1 || echo "Error getting info")
			
			# Extract local details (all with fallbacks)
			app_ref=$(echo "${full_info}" | grep "^Ref:" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "N/A")
			app_arch=$(echo "${full_info}" | grep "^Arch:" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "N/A")
			app_branch=$(echo "${full_info}" | grep "^Branch:" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "N/A")
			app_origin=$(echo "${full_info}" | grep "^Origin:" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "N/A")
			app_install_size=$(echo "${full_info}" | grep "^Installed size:" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "N/A")
			
			# Fetch additional info from Flathub API (with fallback)
			flathub_data=$(curl -s "https://flathub.org/api/v2/appstream/${selected_app}" 2>/dev/null || echo "{}")
			
			# Try to extract Flathub details (all with fallbacks)
			app_developer=$(echo "${flathub_data}" | jq -r '.developer_name // "N/A"' 2>/dev/null || echo "N/A")
			app_license=$(echo "${flathub_data}" | jq -r '.project_license // "N/A"' 2>/dev/null || echo "N/A")
			app_homepage=$(echo "${flathub_data}" | jq -r '.urls.homepage // "N/A"' 2>/dev/null || echo "N/A")
			app_categories=$(echo "${flathub_data}" | jq -r '.categories[]? // empty' 2>/dev/null | tr '\n' ', ' | sed 's/,$//' 2>/dev/null || echo "N/A")
			
			# Build info text (works even if Flathub failed)
			if [[ "${app_developer}" != "N/A" ]]; then
				info_text="<b>Name:</b> ${app_name}
<b>App ID:</b> ${selected_app}
<b>Version:</b> ${app_version}
<b>Description:</b> ${app_description}

<b>Developer:</b> ${app_developer}
<b>License:</b> ${app_license}
<b>Categories:</b> ${app_categories}
<b>Homepage:</b> ${app_homepage}

<b>Installation Details:</b>
<b>Architecture:</b> ${app_arch}
<b>Branch:</b> ${app_branch}
<b>Origin:</b> ${app_origin}
<b>Installed Size:</b> ${app_install_size}"
			else
				# Minimal fallback
				info_text="<b>Name:</b> ${app_name}
<b>App ID:</b> ${selected_app}
<b>Version:</b> ${app_version}
<b>Description:</b> ${app_description}

<b>Installation Details:</b>
<b>Architecture:</b> ${app_arch}
<b>Branch:</b> ${app_branch}
<b>Origin:</b> ${app_origin}
<b>Installed Size:</b> ${app_install_size}"
			fi
			
			# Show dialog (ignore exit code)
			zenity --info \
				--title="App Info: ${app_name}" \
				--text="${info_text}" \
				--width=600 \
				--height=450 2>/dev/null || true
			
			# Always exit subshell with success
			exit 0
		)
			
	elif [[ ${button_pressed} -eq 6 ]]; then
		# Update button pressed
		(
			echo "10" ; echo "# Updating ${app_name}..."
			flatpak --user update "${selected_app}" -y 2>&1
			exit_code=$?
			if [[ ${exit_code} -eq 0 ]]; then
				echo "100" ; echo "# Update complete!"
			else
				echo "# Update failed!"
				exit ${exit_code}
			fi
		) | zenity --progress \
			--title="Updating ${app_name}" \
			--text="Updating..." \
			--percentage=0 \
			--auto-close \
			--width=400 \
			--height=150
		
		if [[ $? -eq 0 ]]; then
			zenity --info \
				--title="Update Complete" \
				--text="<b>${app_name}</b> has been updated successfully!" \
				--width=400 \
				--height=150
		else
			zenity --error \
				--title="Update Failed" \
				--text="Failed to update <b>${app_name}</b>.\n\nPlease check the log file: ${LOG}" \
				--width=400 \
				--height=150
		fi
		
	elif [[ ${button_pressed} -eq 7 ]]; then
		# Uninstall button pressed
		zenity --question \
			--title="Confirm Uninstall" \
			--text="Are you sure you want to uninstall <b>${app_name}</b>?" \
			--width=400 \
			--height=150
		
		if [[ $? -eq 0 ]]; then
			# Uninstall the app
			(
				echo "10" ; echo "# Uninstalling ${app_name}..."
				flatpak --user uninstall "${selected_app}" -y 2>&1
				exit_code=$?
				if [[ ${exit_code} -eq 0 ]]; then
					echo "100" ; echo "# Uninstall complete!"
				else
					echo "# Uninstall failed!"
					exit ${exit_code}
				fi
			) | zenity --progress \
				--title="Uninstalling ${app_name}" \
				--text="Uninstalling..." \
				--percentage=0 \
				--auto-close \
				--width=400 \
				--height=150
			
			if [[ $? -eq 0 ]]; then
				zenity --info \
					--title="Uninstall Complete" \
					--text="<b>${app_name}</b> has been uninstalled successfully!" \
					--width=400 \
					--height=150
			else
				zenity --error \
					--title="Uninstall Failed" \
					--text="Failed to uninstall <b>${app_name}</b>.\n\nPlease check the log file: ${LOG}" \
					--width=400 \
					--height=150
			fi
		fi
		
	fi
	
	# After any action, return to main menu
	return 0
}

search_and_install_flathub() {
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
		
		if [[ $? -ne 0 || -z "${search_query}" ]]; then
			# User cancelled or entered empty query
			return 0
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
		# Optimize sizing for Steam Deck (1280x800) and other displays
		selected_app=$(zenity --list \
			--title="Flathub Search Results - ${results_count} apps found" \
			--text="Select an app (searched for: '${search_query}'):" \
			--column="App ID" \
			--column="Name" \
			--column="Description" \
			--column="Status" \
			"${list_args[@]}" \
			--width=750 \
			--height=450 \
			--print-column=1)
		
		if [[ $? -ne 0 || -z "${selected_app}" ]]; then
			# User cancelled selection, return to main menu
			return 0
		fi
		
		# Get app details
		app_name=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .name')
		app_summary=$(echo "${search_results}" | jq -r --arg id "${selected_app}" '.hits[] | select(.app_id == $id) | .summary')
		
		# Check if app is already installed
		if echo "${installed_flatpaks}" | grep -q "^${selected_app}$"; then
			# App is installed - offer update or uninstall
			action=$(zenity --list \
				--title="Manage ${app_name}" \
				--text="<b>${app_name}</b> is already installed.\n\n<b>ID:</b> ${selected_app}\n<b>Description:</b> ${app_summary}\n\nWhat would you like to do?" \
				--column="Action" \
				"Update" \
				"Uninstall" \
				"Cancel" \
				--width=500 \
				--height=280)
			
			if [[ "${action}" == "Update" ]]; then
				# Update the app
				(
					echo "10" ; echo "# Updating ${app_name}..."
					flatpak --user update "${selected_app}" -y 2>&1
					exit_code=$?
					if [[ ${exit_code} -eq 0 ]]; then
						echo "100" ; echo "# Update complete!"
					else
						echo "# Update failed!"
						exit ${exit_code}
					fi
				) | zenity --progress \
					--title="Updating ${app_name}" \
					--text="Updating..." \
					--percentage=0 \
					--auto-close \
					--width=400 \
					--height=150
				
				if [[ $? -eq 0 ]]; then
					zenity --info \
						--title="Update Complete" \
						--text="<b>${app_name}</b> has been updated successfully!" \
						--width=400 \
						--height=150
				else
					zenity --error \
						--title="Update Failed" \
						--text="Failed to update <b>${app_name}</b>.\n\nPlease check the log file: ${LOG}" \
						--width=400 \
						--height=150
				fi
				
			elif [[ "${action}" == "Uninstall" ]]; then
				# Confirm uninstall
				zenity --question \
					--title="Confirm Uninstall" \
					--text="Are you sure you want to uninstall <b>${app_name}</b>?" \
					--width=400 \
					--height=150
				
				if [[ $? -eq 0 ]]; then
					# Uninstall the app
					(
						echo "10" ; echo "# Uninstalling ${app_name}..."
						flatpak --user uninstall "${selected_app}" -y 2>&1
						exit_code=$?
						if [[ ${exit_code} -eq 0 ]]; then
							echo "100" ; echo "# Uninstall complete!"
						else
							echo "# Uninstall failed!"
							exit ${exit_code}
						fi
					) | zenity --progress \
						--title="Uninstalling ${app_name}" \
						--text="Uninstalling..." \
						--percentage=0 \
						--auto-close \
						--width=400 \
						--height=150
					
					if [[ $? -eq 0 ]]; then
						# Refresh installed list
						installed_flatpaks=$(flatpak list --app --columns=application 2>/dev/null || echo "")
						
						zenity --info \
							--title="Uninstall Complete" \
							--text="<b>${app_name}</b> has been uninstalled successfully!" \
							--width=400 \
							--height=150
					else
						zenity --error \
							--title="Uninstall Failed" \
							--text="Failed to uninstall <b>${app_name}</b>.\n\nPlease check the log file: ${LOG}" \
							--width=400 \
							--height=150
					fi
				fi
			fi
		else
			# App is not installed - offer to install
			zenity --question \
				--title="Confirm Installation" \
				--text="Install the following app?\n\n<b>Name:</b> ${app_name}\n<b>ID:</b> ${selected_app}\n<b>Description:</b> ${app_summary}\n\nThe app will be installed with user-level permissions." \
				--width=500 \
				--height=200
			
			if [[ $? -eq 0 ]]; then
				# Install the app with progress dialog
				(
					echo "10" ; echo "# Installing ${app_name}..."
					update_install_flatpak "${app_name}" "${selected_app}" 2>&1
					exit_code=$?
					if [[ ${exit_code} -eq 0 ]]; then
						echo "100" ; echo "# Installation complete!"
					else
						echo "# Installation failed!"
						exit ${exit_code}
					fi
				) | zenity --progress \
					--title="Installing ${app_name}" \
					--text="Installing..." \
					--percentage=0 \
					--auto-close \
					--width=400 \
					--height=150
				
				install_status=$?
				
				if [[ ${install_status} -eq 0 ]]; then
					# Refresh installed list
					installed_flatpaks=$(flatpak list --app --columns=application 2>/dev/null || echo "")
					
					# Installation successful
					zenity --info \
						--title="Installation Complete" \
						--text="<b>${app_name}</b> has been installed successfully!\n\nApp ID: ${selected_app}" \
						--width=400 \
						--height=150
				else
					# Installation failed
					zenity --error \
						--title="Installation Failed" \
						--text="Failed to install <b>${app_name}</b>.\n\nPlease check the log file: ${LOG}" \
						--width=400 \
						--height=150
				fi
			fi
		fi
		
		# Ask if user wants to search for more apps
		zenity --question \
			--title="Install More Apps?" \
			--text="Do you want to search for and install another app?" \
			--width=400 \
			--height=150
		
		if [[ $? -ne 0 ]]; then
			return 0
		fi
	done
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

main() {
	######################################################
	# Set Zenity margins based on screen resolution
	######################################################

	if ! ${CLI}; then
		# Height in px of the top system bar
		TOPM_ARGIN="${TOP_MARGIN:=27}"
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

	######################################################################
	# Pre-reqs
	######################################################################

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

	######################################################################
	# Update software based on selection
	# Skip if using CLI
	######################################################################

	if ! ${CLI}; then
		ask=$(
			zenity --list --title="Update which softare component?" \
				--column=0 \
				"Update All Software" \
				"Update Core Software" \
				"Update Emulators and Associated Software" \
				"Update User Flatpaks" \
				"Update User Binaries" \
				"Update Utilities (miscellaneous)" \
				"Search and Install from Flathub" \
				"Show Installed Flatpaks" \
				--cancel-label="Exit" \
				--width ${W} \
				--height ${H} \
				--hide-header
		)
		if [[ $? -ne 0 ]]; then
			# Exit button pressed, exit cleanly
			echo "[INFO] Exiting..."
			exit 0
		fi

		echo "[INFO] Choice entered: '${ask}'"
	fi

	if [[ "${ask}" == "Update All Software" || ${ALL} ]]; then
		update_core_software
		update_emulator_software
		update_user_binaries
		update_user_flatpaks
	else
		if [[ "${ask}" == "Update Emulators and Associated Software" || ${UPDATE_EMULATORS} ]]; then
			update_emulator_software
		elif [[ "${ask}" == "Update Core Software" || ${CORE_SOFTWARE} ]]; then
			update_core_software
		elif [[ "${ask}" == "Update User Flatpaks" || ${USER_FLATPAKS} ]]; then
			update_user_flatpaks
		elif [[ "${ask}" == "Update User Binaries" || ${USER_BINARIES} ]]; then
			update_user_binaries
		elif [[ "${ask}" == "Search and Install from Flathub" ]]; then
			search_and_install_flathub
		elif [[ "${ask}" == "Show Installed Flatpaks" ]]; then
			show_installed_flatpaks
		fi
	fi

	######################################################################
	# Cleanup
	######################################################################
	echo -e "\n[INFO] Marking any ELF executables in ${APP_LOC} executable"
	for bin in $(find ${APP_LOC} -type f -exec file {} \; |
		grep ELF |
		awk -F':' '{print $1}' |
		grep -vE ".so|debug"); do
		echo "[INFO] Marking ${bin} executable"
		chmod +x "${bin}"
	done

	# Pause a bit when running GameMode
	if ! ${CLI}; then
		sleep 2
		exit 0
	fi

}

# Run main (logging is handled by launcher)
main
echo "[INFO] Updater completed successfully"
