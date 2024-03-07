#!/bin/bash
# Spawns a new terminal window to run the script

# Update git source if possible first
mkdir -p "${HOME}/.local/bin"
curl -o "${HOME}/.local/bin/update-emulators.sh.new" "https://raw.githubusercontent.com/mdeguzis/SteamOS-Tools/master/utilities/update-emulators/update-emulators.sh"; sleep 3 | zenity --progress --auto-close --pulsate --text="Fetching the latest update-emulators.sh script" --title="Updater" --width=600 --height=250 2>/dev/null

if [[ $? -eq 0 ]]; then
	mv "${HOME}/.local/bin/update-emulators.sh.new" "${HOME}/.local/bin/update-emulators.sh"
else
	rm -f "${HOME}/.local/bin/update-emulators.sh.new"
fi
chmod +x "${HOME}/.local/bin/update-emulators.sh"

# Ignore dumb .so warnings by setting LD_PRELOAD to undefined
export LD_PRELOAD=""
if [[ -f "/usr/bin/konsole" ]]; then
	konsole -e '$SHELL -c "${HOME}/.local/bin/update-emulators.sh && exit; $SHELL"'
elif [[ -f "/usr/bin/gnome-terminal" ]]; then
	gnome-terminal -e '$SHELL -c "${HOME}/.local/bin/update-emulators.sh && exit; $SHELL"'
else
	echo "[ERROR] Unknown terminal in use"
	exit 1
fi
