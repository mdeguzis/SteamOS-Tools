#!/bin/bash
# Updates AppImage/Flatpak emulators in one go
# Notes:
# 	Where to put files: https://gitlab.com/es-de/emulationstation-de/-/blob/stable-3.0/resources/systems/linux/es_find_rules.xml

# Binaries

set -e -o pipefail

CURDIR="${PWD}"

curlit()
{
	# This function is meat to grab an archive/file out of a page HTML/CSS dump

	name=$1
	target_folder=$2
	search_url=$3
	exe_match=$4

	echo "[INFO] Updating $name (searching for ${exe_match} on page...)"
	curl -q -v "${search_url}" &> "/tmp/results.txt"
	urls=$(awk -F"[><]" '{for(i=1;i<=NF;i++){if($i ~ /a href=.*\//){print "<" $i ">"}}}' "/tmp/results.txt")
	rm -f "/tmp/results.txt"
	urls_to_parse=()
	for url in $urls;
	do
		if $(ech "${url}" | grep -q href) && $(echo "${url}" | grep -qE ${exe_match}); then
			dl_url=$(echo "${url}" | sed 's/.*http/http/;s/".*//')

			# which type?
			echo "[INFO] Found download url: '${dl_url}', processing"
			filename=$(basename -- "${dl_url}")
			file_type=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
			echo "[INFO] Filetype found: ${file_type}"

			# Backup
			if ls "${HOME}/Applications"| grep -qE "${name}.*${dl_type}"; then
				echo "[INFO] Moving old ${dl_type} to .bak"
				echo "[INFO] $(mv -v ${HOME}/Applications/${name}*${dl_type} ${HOME}/Applications/${name}.${dl_type}.bak)"
			fi

			# Handle different file types
			case $file_type in
				"zip")
					curl -sLo "/tmp/${name}.zip" "${dl_url}"
					unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"
					;;
				"appimage")
					curl -LO --output-dir "${HOME}/Applications" "${dl_url}"
					cd "${CURDIR}"
					;;

				*)
					echo "I don't know how to process ${file_type}, skipping..."
					return 0
					;;
			esac
		fi
	done

}

update_emu_flatpak ()
{
	name=$1;
	ID=$2;
	echo "[INFO] Updating $name";
	if ! flatpak update $ID -y; then
		# Install
		flatpak install --user -y --noninteractive $ID
	fi
	flatpak override $ID --filesystem=host --user;
	flatpak override $ID --share=network --user;
}

update_binary ()
{
	name=$1;
	folder_target=$2;
	URL=$3;
	dl_type=$4
	echo "[INFO] Updating $name";

	# The ~/Applicaitons dir is compliant with ES-DE
	if echo "${URL}" | grep -q ".zip"; then
		# Handle direct URL zips
		dl_url="${URL}"

	elif echo "${URL}" | grep -q "github.com"; then
		# Handle github release page
		echo "[INFO] Fetching latet release from ${URL}"
		# Prefer app iamge
		app_image_url_noarch=$(curl -s "${URL}" | awk '/http*AppImage/ {print $2}' | sed 's/"//g')
		app_image_url_arch=$(curl -s "${URL}" | awk '/http.*x*64*AppImage/ {print $2}' | sed 's/"//g')
		app_image_url=$(curl -s "${URL}" | awk '/http.*AppImage/ {print $2}' | sed 's/"//g')
		source_url=$(curl -s "${URL}" | awk "/http.*\/${name}-.*linux.*x64.*tar.gz/ {print \$2}" | sed 's/"//g')
		source_url_alt=$(curl -s "${URL}" | awk "/http.*\/${name}-.*linux.*x86_64.*tar.gz/ {print \$2}" | sed 's/"//g')

		# Set download URL
		# Prefer arch-specific first
		if [[ -n "${app_image_url_arch}" ]]; then
			dl_url="${app_image_url_arch}"
		elif [[ -n "${app_image_url}" ]]; then
			dl_url="${app_image_url}"
		elif [[ -n "${app_image_url_noarch}" ]]; then
			dl_url="${app_image_url_noarch}"
		elif [[ -n "${source_url}" ]]; then
			dl_url="${source_url}"
		elif [[ -n "${source_url_alt}" ]]; then
			dl_url="${source_url}"
		else
			# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28
			echo "[ERROR] Could not get a download url for ${URL}!"
			exit 1
		fi
	fi

	# Download
	echo "[INFO] Downloading ${dl_url}"
	curl -LO --output-dir "/tmp" "${dl_url}"

	# Handle download by type
	file_type=$(echo "${dl_type}" | tr '[:upper:]' '[:lower:]')
	if [[ "${file_type}" == "zip" ]]; then
		if [[ -n "${folder_target}" ]]; then
			unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${folder_target}"
		else
			unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/"
		fi

	elif [[ "${file_type}" == "tar.gz" ]]; then
		tar_file=$(ls -t /tmp/${name}*tar.gz)
		if [[ -z "${tar_file}" ]]; then
			echo "[ERROR] Could not match tar.gz file!"
			exit 1
		fi
		echo "[INFO] Extracting ${tar_file}"
		tar -xf "${tar_file}" -C "$HOME/Applications" 
		rm -rf "${tar_file}"

	elif [[ "${file_type}" == "appimage" ]]; then
		app_image=$(ls -t /tmp/${name}*AppImage)
		mv -v "${app_image}" "${HOME}/Applications"
	else
		echo "[INFO] Failed to handle download!"
		exit 1
	fi

	# Backup
	if ls "${HOME}/Applications"| grep -qE "${name}*${dl_type}"; then
		echo "[INFO] Moving old ${dl_type} to .bak"
		echo "[INFO] $(mv -v ${HOME}/Applications/${name}*${dl_type} ${HOME}/Applications/${name}.${dl_type}.bak)"
	fi

}

update_steam_emu ()
{
	name=$1;
	folder_target=$2
	exec_name=$3

	if [[ -n "${folder_target}" ]]; then
		app_dir="${HOME}/Applications/${name}"
	else
		app_dir="${HOME}/Applications"
	fi
	echo "[INFO] Updating $name"

	emu_location=$(find ~/.steam/steam/steamapps/ -name "${exec_name}")
	emu_dir=$(dirname "${emu_location}")
	if [[ -z "${emu_location}" ]]; then
		echo "[ERROR] Could not find Steam app location for ${name} with exec name ${exec_name} ! Skipping..."
		exit 1
	fi
	mkdir -p "${app_dir}"
	cp -r ${emu_dir}/* "${app_dir}" 
}

main () {
	#####################
	# Pre-reqs
	#####################
	
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

	#####################
	# Flatpak
	#####################
	echo -e "[INFO] Updating emulators (Flatpaks)\n"
	sleep 2
	update_emu_flatpak "RetroArch" "org.libretro.RetroArch"
	update_emu_flatpak "PrimeHack" "io.github.shiiion.primehack"
	update_emu_flatpak "RPCS3" "net.rpcs3.RPCS3"
	update_emu_flatpak "Citra" "org.citra_emu.citra"
	update_emu_flatpak "dolphin-emu" "org.DolphinEmu.dolphin-emu"
	update_emu_flatpak "DuckStation" "org.duckstation.DuckStation"
	update_emu_flatpak "PPSSPP" "org.ppsspp.PPSSPP"
	update_emu_flatpak "Xemu-Emu" "app.xemu.xemu"
	update_emu_flatpak "ScummVM" "org.scummvm.ScummVM"
	update_emu_flatpak "melonDS" "net.kuribo64.melonDS"
	update_emu_flatpak "RMG" "com.github.Rosalie241.RMG"
	update_emu_flatpak "Ryujinx" "org.ryujinx.Ryujinx"

	echo -e "\n[INFO] These cores are installed from the Retorach flatpak: "
	ls ~/.var/app/org.libretro.RetroArch/config/retroarch/cores | column -c 150

	#####################
	# Binaries
	#####################
	echo -e "\n[INFO] Updating binaries"
	sleep 2

	# ZIPs
	update_binary "xenia" "xenia" "https://github.com/xenia-canary/xenia-canary/releases/download/experimental/xenia_canary.zip" "zip"
	update_binary "xenia" "xenia" "https://github.com/xenia-project/release-builds-windows/releases/latest/download/xenia_master.zip" "zip"

	# From GitHub release pages
	# Careful not to get rate exceed here...
	update_binary "Steam-ROM-Manager" "" "https://api.github.com/repos/SteamGridDB/steam-rom-manager/releases/latest" "AppImage"
	update_binary "ryujinx" "" "https://api.github.com/repos/Ryujinx/release-channel-master/releases/latest" "tar.gz"
	update_binary "pcsx2" "" "https://api.github.com/repos/PCSX2/pcsx2/releases/latest" "AppImage"
	update_binary "Cemu" "" "https://api.github.com/repos/cemu-project/Cemu/releases/latest" "AppImage"
	update_binary "Vita3k" "" "https://api.github.com/repos/Vita3K/Vita3K/releases/latest" "AppImage"

	# From web scrape
	curlit "rpcs3" "" "https://rpcs3.net/download" ".*rpcs3.*_linux64.AppImage"
	curlit "BigPEmu" "" "https://www.richwhitehouse.com/jaguar/index.php?content=download" ".*BigPEmu.*[0-9].zip"

	#####################
	# Steam
	#####################
	echo -e "\n[INFO] Symlinking any emulators from Steam"
	sleep 2
	# https://steamdb.info/app/1147940/
	update_steam_emu "3dSen" "3dSen" "3dSen.exe"

}

main 2>&1 | tee "/tmp/emulator-updates.log"
echo "[INFO] Done!"
echo "[INFO] Log: /tmp/emulator-updates.log"
