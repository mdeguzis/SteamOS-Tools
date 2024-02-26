#!/bin/bash
# Updates AppImage/Flatpak emulators in one go

# Binaries
#bash ${HOME}/.config/EmuDeck/backend/tools/binupdate/binupdate.sh
#!/bin/bash

curlit()
{
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
			echo "Found download url: ${dl_url}, processing"
			filename=$(basename -- "${dl_url}")
			file_type="${filename##*.}"
			case $file_type in
				"zip")
					echo "Got a ZIP file"
					curl -sLo "/tmp/${name}.zip" "${dl_url}"
					unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"
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

update_windows_exe ()
{
	name=$1;
	URL=$2;
	echo "[INFO] Updating $name";

	# Git repo releases page? get latest
	# The ~/Applicaitons dir is compliant with ES-DE
	if echo "${URL}" | grep -q "zip"; then
		echo "[INFO] Downloading and extracting ZIP for ${name}"
		curl -sLo "/tmp/${name}.zip" "${URL}"
		unzip -o "/tmp/${name}.zip" -d "${HOME}/Applications/${name}"
	fi

}

update_steam_emu ()
{
	name=$1;
	exec_name=$2
	app_dir="${HOME}/Applications/${name}"
	echo "[INFO] Updating $name"

	emu_location=$(find ~/.steam/steam/steamapps/ -name "${exec_name}")
	if [[ -z "${emu_location}" ]]; then
		echo "[ERROR] Could not find Steam app location for ${name} with exec name ${exec_name} ! Skipping..."
		return
	fi
	mkdir -p "${app_dir}"
	cp -v "${emu_location}" "${app_dir}" 
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

echo -e "[INFO] Updating emulators (Flatpaks)\n"
sleep 3
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

echo -e "\n[INFO] Updating Windows EXE's (e.g. xenia))"
update_windows_exe "xenia" "https://github.com/xenia-canary/xenia-canary/releases/download/experimental/xenia_canary.zip"
update_windows_exe "xenia" "https://github.com/xenia-project/release-builds-windows/releases/latest/download/xenia_master.zip"

echo -e "\n[INFO] Symlinking any emulators from Steam"

# https://steamdb.info/app/1147940/
update_steam_emu "3dSen" "3dSen.exe"

echo -e "[INFO] Updating emulators via webscraping\n"
curlit "BigPEmu" "https://www.richwhitehouse.com/jaguar/index.php?content=download" ".*BigPEmu.*[0-9].zip"
