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
	search_url=$2
	exe_match=$3
	echo "[INFO] Updating $name (search for ${exe_match} on page"
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
			case $file_type in
				"zip")
					curl -sLo "/tmp/${name}.zip" "${dl_url}"
					unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"
					;;
				"appimage")
					cd "${HOME}/Applications"
					if ls | grep -qE "${name}.*AppImage"; then
						echo "[INFO] Moving old ${dl_type} to .bak"
						echo "[INFO] $(mv -v ${name}*AppImage ${name}.AppImage.bak)"
					fi
					curl -LO "${dl_url}"
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
	flatpak update $ID -y;
	flatpak override $ID --filesystem=host --user;
	flatpak override $ID --share=network --user;
}

update_binary ()
{
	name=$1;
	URL=$2;
	dl_type=$3
	echo "[INFO] Updating $name";

	# The ~/Applicaitons dir is compliant with ES-DE
	if echo "${URL}" | grep -q ".zip"; then
		# Handle direct URL zips
		echo "[INFO] Downloading and extracting ZIP for ${name}"
		curl -sLo "/tmp/${name}.zip" "${URL}"
		unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"

	elif echo "${URL}" | grep -q "github.com"; then
		# Handle github release page
		echo "[INFO] Fetching latet release from ${URL}"
		# Prefer app iamge
		app_image_url=$(curl -s "${URL}" | awk '/http.*AppImage/ {print $2}' | sed 's/"//g')

		# Set download URL
		if [[ -z" ${app_image_url}" ]]; then
			dl_url="${app_image_url}"
		else
			echo "[ERROR] Could not get a download url for ${URL}!"
			return 0
		fi

		# Get release
		cd "${HOME}/Applications"
		if ls | grep -qE "${name}.*${dl_type}"; then
			echo "[INFO] Moving old ${dl_type} to .bak"
			echo "[INFO] $(mv -v ${name}*${dl_type} ${name}.AppImage.bak)"
		fi
		echo "[INFO] Downloading ${dl_url}"
		curl -LO "${dl_url}"

	else
		cd "${HOME}/Applications"
		if ls | grep -qE "${name}.*AppImage"; then
			echo "[INFO] Moving old ${dl_type} to .bak"
			echo "[INFO] $(mv -v ${name}*AppImage ${name}.AppImage.bak)"
		fi
		echo "[INFO] Downloading ${dl_url}"
		curl -LO "${dl_url}"
	fi

}

update_steam_emu ()
{
	name=$1;
	exec_name=$2
	app_dir="${HOME}/Applications/${name}"
	echo "[INFO] Updating $name"

	emu_location=$(find ~/.steam/steam/steamapps/ -name "${exec_name}")
	emu_dir=$(dirname "${emu_location}")
	if [[ -z "${emu_location}" ]]; then
		echo "[ERROR] Could not find Steam app location for ${name} with exec name ${exec_name} ! Skipping..."
		return
	fi
	mkdir -p "${app_dir}"
	cp -r ${emu_dir}/* "${app_dir}" 
}

update_from_curl ()
{
	name=$1;
	url_match=$2
	app_dir="${HOME}/Applications/${name}"
	echo "[INFO] Fetching release from ${url_match} for ${name}"

	mkdir -p "${app_dir}"
	cp -v "${emu_location}" "${app_dir}" 
}

main () {
	#####################
	# Flatpak
	#####################
	echo -e "[INFO] Updating emulators (Flatpaks)\n"
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

	echo -e "\n[INFO] These cores are installed from the Retorach flatpak: "
	ls ~/.var/app/org.libretro.RetroArch/config/retroarch/cores | column -c 150

	#####################
	# Binaries
	#####################
	echo -e "\n[INFO] Updating binaries"
	# ZIPs
	update_binary "xenia" "https://github.com/xenia-canary/xenia-canary/releases/download/experimental/xenia_canary.zip"
	# From GitHub release pages
	update_binary "Steam-ROM-Manager" "https://api.github.com/repos/SteamGridDB/steam-rom-manager/releases/latest" "AppImage"
	# From web scrape
	curlit "rpcs3" "https://rpcs3.net/download" ".*rpcs3.*_linux64.AppImage"
	curlit "BigPEmu" "https://www.richwhitehouse.com/jaguar/index.php?content=download" ".*BigPEmu.*[0-9].zip"

	#binTable+=(TRUE "Steam Rom Manager" "srm")
	#binTable+=(TRUE "GameBoy / Color / Advance Emu" "mgba")
	#binTable+=(TRUE "Nintendo Switch Emu" "yuzu (mainline)")
	#binTable+=(TRUE "Nintendo Switch Emu" "yuzu (early access)")
	#binTable+=(TRUE "Nintendo Switch Emu" "ryujinx")
	#binTable+=(TRUE "Sony PlayStation 2 Emu" "pcsx2-qt")
	#binTable+=(TRUE "Nintendo WiiU Emu (Proton)" "cemu (win/proton)")
	#binTable+=(TRUE "Nintendo WiiU Emu (Native)" "cemu (native)")
	#binTable+=(TRUE "Sony PlayStation Vita Emu" "vita3k")
	#binTable+=(TRUE "Xbox 360 Emu" "xenia") 

	#####################
	# Steam
	#####################
	echo -e "\n[INFO] Symlinking any emulators from Steam"
	# https://steamdb.info/app/1147940/
	update_steam_emu "3dSen" "3dSen.exe"

}

main 2>&1 | tee "/tmp/emulator-updates.log"
echo "[INFO] Log: /tmp/emulator-updates.log"
