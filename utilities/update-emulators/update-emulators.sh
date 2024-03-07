#!/bin/bash
# Updates AppImage/Flatpak emulators in one go
# Notes:
# 	Where to put files: https://gitlab.com/es-de/emulationstation-de/-/blob/stable-3.0/resources/systems/linux/es_find_rules.xml
# 	Emulator files: https://emulation.gametechwiki.com/index.php/Emulator_files

# Binaries

set -e -o pipefail

CURDIR="${PWD}"

curlit()
{
	# This function is meantt to grab an archive/file out of a page HTML/CSS dump

	name=$1
	target_folder=$2
	search_url=$3
	exe_match=$4

	echo -e "\n[INFO] Updating $name (searching for ${exe_match} on page...)"
	curl -q -v "${search_url}" &> "/tmp/results.txt"
	urls=$(awk -F"[><]" '{for(i=1;i<=NF;i++){if($i ~ /a href=.*\//){print "<" $i ">"}}}' "/tmp/results.txt")
	rm -f "/tmp/results.txt"
	urls_to_parse=()
	for url in $urls;
	do
		if $(echo "${url}" | grep -q href) && $(echo "${url}" | grep -qE ${exe_match}); then
			dl_url=$(echo "${url}" | sed 's/.*http/http/;s/".*//')

			# which type?
			echo "[INFO] Found download url: '${dl_url}', processing"
			filename=$(basename -- "${dl_url}")
			file_type=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
			echo "[INFO] Filetype found: ${file_type}"

			# Backup
			if ls "${HOME}/Applications"| grep -qE ${name}*${dl_type}; then
				echo "[INFO] Moving old ${dl_type} to .bak in /tmp"
				echo "[INFO] $(mv -v ${HOME}/Applications/${name}*${dl_type} /tmp/${name}.${dl_type}.bak)"
			fi

			# Handle different file types
			case $file_type in
				"zip")
					curl -sLo "/tmp/${name}.zip" "${dl_url}"
					unzip -fo "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"
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
	echo -e "\n[INFO] Updating $name";
	if ! flatpak --user update $ID -y; then
		sleep 2
		# Show version
		# Install
		flatpak install --user -y --noninteractive $ID
		if [[ $? -ne 0 ]]; then
			echo "[ERROR] Failed to install Flatpak!"
			exit 1
		fi
	#else
	#	flatpak --user info $ID | grep Version | sed 's/\ //g'
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
	curl_options="-LO --output-dir /tmp"

	echo -e "\n[INFO] Updating binary for $name";

	# The ~/Applications dir is compliant with ES-DE
	if echo "${URL}" | grep -q ".zip"; then
		# Handle direct URL zips
		dl_url="${URL}"

	elif echo "${URL}" | grep -q "gitlab.com/api"; then
		echo "[INFO] Fetching latet release from ${URL}"
		latest_release=$(curl -Ls "${URL}" | jq -r '.assets.links[] | select(.name | test('\"$name.*x64.AppImage\"'))')
		artifact_name=$(echo "${latest_release}" | jq -r '.name')
		dl_url=$(echo "${latest_release}" | jq -r '.direct_asset_url')
		# Use -J and --clobber to attach the remote name and overwrite
		curl_options="--clobber -JLO --output-dir /tmp"

	elif echo "${URL}" | grep -q "github.com"; then
		# Handle github release page
		echo "[INFO] Fetching latet release from ${URL}"
		# Prefer app iamge
		# Set download URL
		# Prefer arch-specific first
		# If not /latest, assume pre-release
		if ! echo "${URL}" | grep -q "latest"; then
			collected_urls=$(curl -s "${URL}" | jq -r 'map(select(.prerelease)) | first | .assets[] | .browser_download_url')
		else
			collected_urls=$(curl -s "${URL}" | jq -r '.assets[] | .browser_download_url')
		fi

		for this_url in ${collected_urls};
		do
			# Prefer AppImage
			if echo "${this_url}" | grep -qE "http.*AppImage$"; then
				dl_url="${this_url}"
				break
			elif echo  "${this_url}" | grep -qE "http.*x.*64.*AppImage$"; then
				dl_url="${this_url}"
				break
			elif echo "${this_url}" | grep -qE "http.*${name}-.*linux.*x*64.*tar.gz$"; then
				dl_url="${this_url}"
				break
			fi
		done

		if [[ -z "${dl_url}" ]]; then
			# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28
			echo "[ERROR] Could not get a download url for ${URL}!"
			exit 1
		fi
	fi

	# Backup
	if ls "${HOME}/Applications"| grep -qE ${name}*${dl_type}; then
		echo "[INFO] Moving old ${dl_type} to .bak in /tmp"
		echo "[INFO] $(mv -v ${HOME}/Applications/${name}*${dl_type} /tmp/${name}.${dl_type}.bak)"
	fi

	# Download
	echo "[INFO] Downloading ${dl_url}"
	cmd="curl ${curl_options} ${dl_url}"
	eval "${cmd}"

	# Handle download by type
	file_type=$(echo "${dl_type}" | tr '[:upper:]' '[:lower:]')
	if [[ "${file_type}" == "zip" ]]; then
		if [[ -n "${folder_target}" ]]; then
			unzip -fo "/tmp/${name}.zip" -d "${HOME}/Applications/${folder_target}"
		else
			unzip -fo "/tmp/${name}.zip" -d "${HOME}/Applications/"
		fi

	elif [[ "${file_type}" == "tar.gz" ]]; then
		tar_file=$(ls -t /tmp/${name}*tar.gz | head -n 1)
		if [[ -z "${tar_file}" ]]; then
			echo "[ERROR] Could not match tar.gz file!"
			exit 1
		fi

		echo "[INFO] Extracting ${tar_file}"
		if [[ -n "${folder_target}" ]]; then
			mkdir -p "${HOME}/Applications/${folder_target}"
			tar -xvf "${tar_file}" -C "$HOME/Applications/${folder_target}" 
		else
			tar -xvf "${tar_file}" -C "$HOME/Applications" 
		fi

		rm -rf "${tar_file}"

	elif [[ "${file_type}" == "appimage" ]]; then
		app_image=$(ls -t /tmp/${name}*AppImage)
		if [[ -n "${folder_target}" ]]; then
			mkdir -p "${HOME}/Applications/${folder_target}"
			mv -v "${app_image}" "${HOME}/Applications/${folder_target}"
		else
			mv -v "${app_image}" "${HOME}/Applications"
		fi
	else
		echo "[INFO] Failed to handle download!"
		exit 1
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

	emu_location=$(find ~/.steam/steam/steamapps/ -name "${exec_name}" || true)
	emu_dir=$(dirname "${emu_location}")
	if [[ -z "${emu_location}" ]]; then
		echo "[ERROR] Could not find Steam app location for ${name} with exec name ${exec_name} ! Skipping..."
		return
	fi
	mkdir -p "${app_dir}"
	cp -r ${emu_dir}/* "${app_dir}" 
}

main () {
	#####################
	# Pre-reqs
	#####################

    mkdir -p "${HOME}/Applications"
	
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
	# RIP Citra
	# update_emu_flatpak "Citra" "org.citra_emu.citra"
	update_emu_flatpak "dolphin-emu" "org.DolphinEmu.dolphin-emu"
	update_emu_flatpak "DOSBox" "com.dosbox.DOSBox"
	update_emu_flatpak "DOSBox-Staging" "io.github.dosbox-staging"
	update_emu_flatpak "DuckStation" "org.duckstation.DuckStation"
	update_emu_flatpak "Lutris" "net.lutris.Lutris"
	update_emu_flatpak "MAME" "org.mamedev.MAME"
	update_emu_flatpak "melonDS" "net.kuribo64.melonDS"
	update_emu_flatpak "Mupen64Plus (GUI)" "com.github.Rosalie241.RMG"
	update_emu_flatpak "PPSSPP" "org.ppsspp.PPSSPP"
	update_emu_flatpak "PrimeHack" "io.github.shiiion.primehack"
	update_emu_flatpak "RetroArch" "org.libretro.RetroArch"
	update_emu_flatpak "RMG" "com.github.Rosalie241.RMG"
	update_emu_flatpak "RPCS3" "net.rpcs3.RPCS3"
	update_emu_flatpak "Ryujinx" "org.ryujinx.Ryujinx"
	update_emu_flatpak "ScummVM" "org.scummvm.ScummVM"
	update_emu_flatpak "Xemu-Emu" "app.xemu.xemu"

    if [[ -d "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" ]]; then
        echo -e "\n[INFO] These cores are installed from the Retorach flatpak: "
        ls "${HOME}/.var/app/org.libretro.RetroArch/config/retroarch/cores" | column -c 150
    fi

	#####################
	# Binaries
	#####################
	echo -e "\n[INFO] Updating binaries"
	sleep 2

	# Wine / Proton
	update_binary "wine-staging_ge-proton" "Proton" "https://api.github.com/repos/mmtrt/WINE_AppImage/releases/latest" "AppImage"

	# ZIPs
	update_binary "xenia_master" "xenia" "https://github.com/xenia-project/release-builds-windows/releases/latest/download/xenia_master.zip" "zip"
	update_binary "xenia_canary" "xenia" "https://github.com/xenia-canary/xenia-canary/releases/download/experimental/xenia_canary.zip" "zip"
    # Note that the Panda3DS AppImage name is oddly named: "Alber-x86_64.AppImage"
	update_binary "Panda3DS" "" "https://nightly.link/wheremyfoodat/Panda3DS/workflows/Qt_Build/master/Linux executable.zip" "zip"

	# From GitHub release pages
	# Careful not to get rate exceeded here...
	update_binary "ES-DE" "" "https://gitlab.com/api/v4/projects/18817634/releases/permalink/latest" "AppImage"
	update_binary "Steam-ROM-Manager" "" "https://api.github.com/repos/SteamGridDB/steam-rom-manager/releases/latest" "AppImage"
	update_binary "ryujinx" "" "https://api.github.com/repos/Ryujinx/release-channel-master/releases/latest" "tar.gz"
	update_binary "pcsx2" "" "https://api.github.com/repos/PCSX2/pcsx2/releases/latest" "AppImage"
	# No Cemu latest tag has a Linux AppImage, must use use pre-releases
	update_binary "Cemu" "" "https://api.github.com/repos/cemu-project/Cemu/releases" "AppImage"
	update_binary "Vita3K" "" "https://api.github.com/repos/Vita3K/Vita3K/releases/latest" "AppImage"

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

	#####################
	# Cleanup
	#####################
	echo "[INFO] Marking any ELF executables in ${HOME}/Applications executable"
	for bin in $(find ~/Applications -type f -exec file {} \; \
		| grep ELF \
		| awk -F':' '{print $1}' \
		| grep -vE ".so|debug")
	do 
		echo "[INFO] Marking ${bin} executable"
		chmod +x "${bin}"
	done
	
}

main 2>&1 | tee "/tmp/emulator-updates.log"
echo "[INFO] Done!"
echo "[INFO] Log: /tmp/emulator-updates.log. Exiting."
# Pause a bit when running GameMode
sleep 5

