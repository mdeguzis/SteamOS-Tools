#!/bin/bash
# Updates AppImage/Flatpak emulators in one go
# Notes:
#	Where to put files: https://gitlab.com/es-de/emulationstation-de/-/blob/stable-3.0/resources/systems/linux/es_find_rules.xml
#	Emulator files: https://emulation.gametechwiki.com/index.php/Emulator_files

set -e -o pipefail

VERSION="0.8.6"
CURDIR="${PWD}"
BACKUP_LOC="/tmp/update-emulators-backup"
CONFIG_ROOT="${HOME}/.config/steamos-tools"
APP_LOC="${HOME}/Applications"
LOG="/tmp/steamos-software-updater.log"
CLI=false
if [[ -z ${DISPLAY} ]]; then
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

	elif [[ "${file_type}" == "tar.gz" ]]; then
		tar_file=$(ls -t /tmp/${name}*tar.gz | head -n 1)
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
	update_binary "xenia_canary" "xenia" "" "https://github.com/xenia-canary/xenia-canary/releases/download/experimental/xenia_canary.zip" "zip"
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
		# xwininfo is built into most OS distributions
		SCREEN_WIDTH=$(xwininfo -root | awk '$1=="Width:" {print $2}')
		SCREEN_HEIGHT=$(xwininfo -root | awk '$1=="Height:" {print $2}')
		W=$((${SCREEN_WIDTH} / 2 - ${RIGHT_MARGIN}))
		H=$((${SCREEN_HEIGHT} / 2 - ${TOP_MARGIN}))

		echo "[INFO] Scren dimensions detected:"
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
				"All" \
				"Core software" \
				"Emulators and associated sofware" \
				"User Flatpaks" \
				"User binaries" \
				"Utilities (miscellaneous)" \
				"Exit" \
				--width ${W} \
				--height ${H} \
				--hide-header
		)
		if [[ $? -ne 0 ]]; then
			# cancel pressed, exit
			exit 0
		fi

		echo "[INFO] Choice entered: '${ask}'"
	fi

	if [[ "${ask}" == "Exit" ]]; then
		exit 0

	elif [[ "${ask}" == "All" || ${ALL} ]]; then
		update_core_software
		update_emulator_software
		update_user_binaries
		update_user_flatpaks
		update_user_misc
	else
		if [[ "${ask}" == "Emulators and associated sofware" || ${UPDATE_EMULATORS} ]]; then
			update_emulator_software
		elif [[ "${ask}" == "Core software" || ${CORE_SOFTWARE} ]]; then
			update_core_software
		elif [[ "${ask}" == "User Flatpaks" || ${USER_FLATPAKS} ]]; then
			update_user_flatpaks
		elif [[ "${ask}" == "User binaries" || ${USER_BINARIES} ]]; then
			update_user_binaries
		elif [[ "${ask}" == "Utilities (miscellaneous)" || ${MISC} ]]; then
			update_user_misc
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

# Run and log
main 2>&1 | tee "${LOG}"
echo "[INFO] Done!"
echo "[INFO] Log: ${LOG}. Exiting."

