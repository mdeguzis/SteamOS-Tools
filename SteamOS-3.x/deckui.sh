#!/bin/bash
# Description: Install/uninstall gamepad UI and/or Gamescope from Steam Deck
# Designed for ChimeraOS
# Resources
#	* gamescope options: https://github.com/Plagman/gamescope/blob/master/src/main.cpp

# Defaults

DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/deckui-tool-${DATE}.log"
LINE="==========================================================="
BETA_CONFIG_FOUND="false"
CLIENT_BETA_CONFIG="${HOME}/.local/share/Steam/package/beta"
DECK_VER="steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d"
DECK_CONF="${HOME}/.config/environment.d/deckui.conf"
VALID_GPU="false"
PERSIST="false"
FORCE_ENABLE="false"
VERIFY_ONLY="false"
ENABLE=""

# Valid GPU vendors at this point are AMD (best case) and Intel.
# See: /usr/share/hwdata/pci.ids
# 0300 and 0302 are VGA/3D class
AMD_VEND_ID="1002"
INTEL_VEND_ID="8086"
PCI_VGA=$(lspci -nm | awk '{print $1 " " $2 " " $3}' | grep -E '300|302')
ACCEPTABLE_GPU_LIST=$(echo "${PCI_VGA}" | grep -E "${AMD_VEND_ID}|${INTEL_VEND_ID}")

# Dynamic vars
if [[ -f ${CLIENT_BETA_CONFIG} ]]; then
	BETA_CONFIG_FOUND="true"
fi

function verify_status() {
	# Check GPU type
	validate_gpu

	# Display current config only
	cat<<-EOF2

	Current configuration:

	Expected beta config file: ${CLIENT_BETA_CONFIG}
	Beta config found: ${BETA_CONFIG_FOUND} 
	Force enable: ${FORCE_ENABLE}
	Persist changes?: ${PERSIST}
	Valid GPU for Gamescope?: ${VALID_GPU}

	EOF2
	exit 0
}

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--enable			Enable the gamepadUI and/or Gamescope (do not persist on reboot)
	--disable			Disable the gamepadUI and/or Gamescope (do not persist on reboot)
	--persist			Persist changes upon reboot.
	--force-enable		        Ignore GPU type restriction and enable Gamescope

	HELP_EOF

}

function gamescope() {
	local ACTION=$1

	if [[ ${ACTION} == "enable" ]]; then
		if [[ ${PERSIST} == "true" ]]; then
            echo "[INFO] Persisting changes"
			sudo systemctl disable lightdm
			sudo systemctl enable gamescope@tty1
		fi
		echo "[INFO] Stopping lightdm"
		sudo systemctl stop lightdm
		echo "[INFO] Starting gamescope session"
		sudo systemctl start gamescope@tty1

	elif [[ ${ACTION} == "disable" ]]; then
		if [[ ${PERSIST} == "true" ]]; then
            echo "[INFO] Persisting changes"
			sudo systemctl disable gamescope@tty1
			sudo systemctl enable lightdm
		fi
		echo "[INFO] Stopping gamescope session"
		sudo systemctl stop gamescope@tty1
		echo "[INFO] Starting lightdm session"
		sudo systemctl start lightdm
	fi
}

function config() {
	local ACTION=$1

	# Env prep
	mkdir -p ~/.config/environment.d

	if [[ ${ACTION} == "enable" ]]; then
		echo "[INFO] Copying beta config into place"
		sudo bash -c "echo ${DECK_VER} > ${CLIENT_BETA_CONFIG}"

		# Add deckui.conf
		echo "[INFO] Copying deckui config into place"
		cat <<-EOF >> "${DECK_CONF}"
		GAMESCOPECMD="gamescope -e -f"
		STEAMCMD="steam -steamos -gamepadui"
		EOF

	elif [[ ${ACTION} == "backup" ]]; then
		# Only backup the file if it does not have steampal in it (specific to Steam Deck at this time)
		# This is to avoid issues with a user running enable when the session already is
		if [[ -f "${CLIENT_BETA_CONFIG}" ]] && ! grep -q "steampal" "${CLIENT_BETA_CONFIG}"; then
			echo "[INFO] Backing up existing ${CLIENT_BETA_CONFIG} to ${CLIENT_BETA_CONFIG}.orig"
			sudo cp "${CLIENT_BETA_CONFIG}" "${CLIENT_BETA_CONFIG}.orig"
		fi

	elif [[ ${ACTION} == "restore" ]]; then
		echo "[INFO] Restoring old configuration"
		rm -f "${DECK_CONF}"
		# Restore client beta config or remove if it never existed
		if [[ -f "${CLIENT_BETA_CONFIG}.orig" ]]; then
			echo "[INFO] Old beta config found, restoring..."
			sudo mv "${CLIENT_BETA_CONFIG}" "${CLIENT_BETA_CONFIG}.orig"
		else
			echo "[INFO] Old beta config NOT found, removing beta config file"
			rm -f "${CLIENT_BETA_CONFIG}"
		fi

	fi
}

function lightdm_fallback() {
	echo "[WARN] Did not find usable GPU for gamescope! Falling back to lightdm"
	sudo systemctl restart lightdm
}

function session () {
	local ACTION=$1

	# Validate GPU type
	validate_gpu

	if [[ ${ACTION} == "enable" ]]; then
		if [[ ${VALID_GPU} == "true" ]]; then
			echo "[INFO] Found usable GPU for gamescope, enabling..."
			gamescope enable
		else
			lightdm_fallback
		fi

	elif [[ ${ACTION} == "disable" ]]; then
		# Remove configs"
		rm -f "${DECK_CONF}"
		gamescope disable
		config restore	

	fi

}

function restart_steam () {
	echo "[INFO] Restarting Steam..."
	pkill steam
}

function validate_gpu () {
	if [[ -n ${ACCEPTABLE_GPU_LIST} ]]; then
		VALID_GPU="true"
	fi

	if [[ ${FORCE_ENABLE} == "true" ]]; then
		echo "[WARN] Ignoring GPU type restriction for Gamescope configuration"
		VALID_GPU="true"
	fi
}

main() {
	cat<<-EOF
	${LINE}
	Steam Deck gamepadui installation script (experimental)
	${LINE}

	EOF

	# No options?
	if [[ -z $1 ]]; then
		VERIFY_ONLY="true"
	fi

	while :; do
		case $1 in

			--persist|-p)
				PERSIST="true"
				;;

			--enable|-e)
                ENABLE="true"
				;;
				
			--disable|-d)
                ENABLE="false"
				;;

			--force-enable|-f)
				FORCE_ENABLE="true"
				;;

			--verify|-v)
				VERIFY_ONLY="true"
				;;

			--help|-h)
				show_help;
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

		esac

		# shift args
		shift
	done

	# Information display when no option is given
	if [[ ${VERIFY_ONLY} == "true" ]]; then
		verify_status

    elif [[ ${ENABLE} == "true" ]]; then
        config backup
        config enable
        session enable
        restart_steam

    elif [[ ${ENABLE} == "false" ]]; then
        session disable
        restart_steam

	fi
}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"

# Trim logs
find /tmp -name "deckui-tool-*" -mtime 14 -exec -delete \; 2>/dev/null

