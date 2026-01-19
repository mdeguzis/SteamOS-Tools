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
		--help)
			echo "Using --test to skip updater for local testing"
			exit 0
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

# Log file location
LOG_FILE="/tmp/steamos-software-updater.log"

# Ignore dumb .so warnings by setting LD_PRELOAD to undefined
export LD_PRELOAD=""

# Run the script directly (not in a new terminal) and capture exit code
echo "[INFO] Running updater..."
bash "${SCRIPT_CMD}" 2>&1 | tee "${LOG_FILE}"
EXIT_CODE=${PIPESTATUS[0]}

# Check if script failed
if [[ ${EXIT_CODE} -ne 0 ]]; then
	echo "[ERROR] Updater failed with exit code ${EXIT_CODE}"
	
	# Show error dialog with log if zenity is available
	if command -v zenity &> /dev/null; then
		# Get last 40 lines of log
		if [[ -f "${LOG_FILE}" ]]; then
			log_content=$(tail -n 40 "${LOG_FILE}" 2>/dev/null)
		else
			log_content="Log file not found"
		fi
		
		# Create error text
		error_text="========================================
UPDATER ERROR

Exit Code: ${EXIT_CODE}
Time: $(date)

Recent Log Output (last 40 lines):

${log_content}

Full log file: ${LOG_FILE}
========================================"
		
		# Show in zenity text dialog
		echo "${error_text}" | zenity --text-info \
			--title="Updater Failed - Exit Code ${EXIT_CODE}" \
			--ok-label="Exit" \
			--width=1000 \
			--height=800 \
			--font="Monospace 10"
	fi
	
	exit ${EXIT_CODE}
fi

echo "[INFO] Updater completed successfully"
exit 0
