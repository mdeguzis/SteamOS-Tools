#!/bin/bash
# Spawns a new terminal window to run the script

# Parse command-line arguments
TEST_MODE=false
SCRIPT_ARGS=()

while [[ $# -gt 0 ]]; do
	case $1 in
		--test)
			TEST_MODE=true
			shift
			;;
		*)
			# Collect other arguments to pass to the script
			SCRIPT_ARGS+=("$1")
			shift
			;;
	esac
done

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SCRIPT="${SCRIPT_DIR}/update-software.sh"

# Check if we're in test mode or running from a git repository (for development/testing)
if [[ "${TEST_MODE}" == true ]]; then
	echo "[INFO] Test mode: using local version without update check"
	if [[ ! -f "${LOCAL_SCRIPT}" ]]; then
		echo "[ERROR] Local script not found: ${LOCAL_SCRIPT}"
		exit 1
	fi
	SCRIPT_TO_RUN="${LOCAL_SCRIPT}"
elif [[ -f "${LOCAL_SCRIPT}" ]] && git -C "${SCRIPT_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
	echo "[INFO] Running from git repository, using local version"
	SCRIPT_TO_RUN="${LOCAL_SCRIPT}"
else
	# Production mode: Update from GitHub
	echo "[INFO] Production mode: fetching latest version from GitHub"
	mkdir -p "${HOME}/.local/bin"
	curl -o "${HOME}/.local/bin/update-software.sh.new" "https://raw.githubusercontent.com/mdeguzis/SteamOS-Tools/master/utilities/update-software/update-software.sh" && sleep 3 | zenity --progress --auto-close --pulsate --text="Fetching the latest update-software.sh script" --title="Updater" --width=600 --height=250 2>/dev/null

	if [[ $? -eq 0 ]]; then
		mv "${HOME}/.local/bin/update-software.sh.new" "${HOME}/.local/bin/update-software.sh"
	else
		zenity --info --text="Failed to install new script version, reusing existing script."
		rm -f "${HOME}/.local/bin/update-software.sh.new"
	fi
	chmod +x "${HOME}/.local/bin/update-software.sh"
	SCRIPT_TO_RUN="${HOME}/.local/bin/update-software.sh"
fi

# Build command with any additional arguments
if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
	SCRIPT_CMD="${SCRIPT_TO_RUN} ${SCRIPT_ARGS[*]}"
else
	SCRIPT_CMD="${SCRIPT_TO_RUN}"
fi

# Ignore dumb .so warnings by setting LD_PRELOAD to undefined
export LD_PRELOAD=""

# Launch based on terminal preference
# Detect OS first
if [[ "$(uname)" == "Darwin" ]]; then
	# macOS - use Terminal.app or iTerm2
	if [[ -d "/Applications/iTerm.app" ]]; then
		# iTerm2 if available
		osascript <<-EOF
			tell application "iTerm"
				create window with default profile
				tell current session of current window
					write text "${SCRIPT_CMD}"
				end tell
			end tell
		EOF
	else
		# Default macOS Terminal.app
		osascript <<-EOF
			tell application "Terminal"
				do script "${SCRIPT_CMD}; exit"
				activate
			end tell
		EOF
	fi

# Linux - check for various terminal emulators
elif [[ -f "/usr/bin/xterm" ]]; then
	xterm -fg white -bg black \
		-maximized -fa 'Monospace' -fs 24 \
		-e '$SHELL -c "${SCRIPT_CMD}; exit; $SHELL"'

elif [[ -f "/usr/bin/konsole" ]]; then
	konsole -e '$SHELL -c "${SCRIPT_CMD}; exit; $SHELL"'

elif [[ -f "/usr/bin/gnome-terminal" ]]; then
	gnome-terminal -e '$SHELL -c "${SCRIPT_CMD}; exit; $SHELL"'

elif [[ -f "/usr/bin/kgx" ]]; then
	kgx -e '$SHELL -c "${SCRIPT_CMD}; exit; $SHELL"'

else
	echo "[ERROR] Unknown terminal in use"
	exit 1
fi
