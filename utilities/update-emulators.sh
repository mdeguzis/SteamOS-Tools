#!/bin/bash
# Updates AppImage/Flatpak emulators in one go

# Binaries
#bash ${HOME}/.config/EmuDeck/backend/tools/binupdate/binupdate.sh
#!/bin/bash

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


