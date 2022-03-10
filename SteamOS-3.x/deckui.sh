#!/bin/bash
# Description: Install/uninstall gamepad UI and/or Gamescope from Steam Deck
# Designed for ChimeraOS
# Resources
#   * gamescope options: https://github.com/Plagman/gamescope/blob/master/src/main.cpp

LINE="==========================================================="
OPTION=$1
BETA_CONFIG_FOUND="false"
CLIENT_BETA_CONFIG="${HOME}/.local/share/Steam/package/beta"
DECK_VER="steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d"
DECK_CONF="${HOME}/.config/environment.d/deckui.conf"
VALID_GPU="false"

# Valid GPU vendors at this point are AMD (best case) and Intel.
# See: /usr/share/hwdata/pci.ids
# 0300 and 0302 are VGA/3D class
AMD_VEND_ID="1002"
INTEL_VEND_ID="8086"
PCI_VGA=$(lspci -nm | awk '{print $1 " " $2 " " $3}' | grep -E '300|302')
ACCEPTABLE_GPU_LIST=$(echo ${PCI_VGA} | grep -E "${AMD_VEND_ID}|${INTEL_VEND_ID}")
if [[ -n ${ACCEPTABLE_GPU_LIST} ]]; then
	VALID_GPU="true"
fi

# Dynamic vars
if [[ -f ${CLIENT_BETA_CONFIG} ]]; then
	BETA_CONFIG_FOUND="true"
fi

cat<<-EOF
${LINE}
Steam Deck gamepadui installation script (experimental)
${LINE}

EOF

function verify_status() {
	# Display current config only
	cat<<-EOF2
	Current configuration:
	
	Expected beta config file: ${CLIENT_BETA_CONFIG}
	Beta config found: ${BETA_CONFIG_FOUND}	
	Valid GPU for Gamescope?: ${VALID_GPU}

	EOF2
	exit 0
}

function show_help() {
	cat<<-HELP_EOF
	--help|-h		Show this help page
	--enable		Enable the gamepadUI and/or Gamescope (do not persist on reboot)
	--disable		Disable and revert to stock configuration the user has/had (do not persist on reboot)
	--install		Make changes permanent to system (persist on reboot)
	--uninstall		Remove and revert to stock configuration (persist on reboot)

	HELP_EOF

}

function gamescope() {
	local action=$1

	if [[ ${action} == "install" ]]; then
		echo "[INFO] Stopping lightdm"
		sudo systemctl stop lightdm
		echo "[INFO] Installing gamescope session"
		sudo systemctl enable gamescope@tty1
		sudo systemctl start gamescope@tty1

	elif [[ ${action} == "uninstall" ]]; then
		echo "[INFO] Uninstalling gamescope session"
		sudo systemctl stop gamescope@tty1
		sudo systemctl disable gamescope@tty1
		echo "[INFO] Starting lightdm session"
		sudo systemctl enable lightdm
		sudo systemctl start lightdm

	elif [[ ${action} == "enable" ]]; then
		echo "[INFO] Stopping lightdm"
		sudo systemctl stop lightdm
		echo "[INFO] Starting gamescope session"
		sudo systemctl start gamescope@tty1

	elif [[ ${action} == "disable" ]]; then
		echo "[INFO] Disabling gamescope session"
		sudo systemctl stop gamescope@tty1
		sudo systemctl disable gamescope@tty1
		echo "[INFO] Starting lightdm session"
		sudo systemctl enable lightdm
		sudo systemctl start lightdm
	fi

}

function config() {
	local action=$1

	# Env prep
	mkdir -p ~/.config/environment.d

	if [[ ${action} == "install" ]]; then
		echo "[INFO] Copying beta config into place"
		sudo bash -c "echo ${DECK_VER} > ${CLIENT_BETA_CONFIG}"

		# Add deckui.conf
		echo "[INFO] Copying deckui config into place"
		cat <<-EOF >> "${DECK_CONF}"
		GAMESCOPECMD="gamescope -e -f --steam -f"
		STEAMCMD="steam -steamos -gamepadui"
		EOF

	elif [[ ${action} == "backup" ]]; then
		if [[ -f ${CLIENT_BETA_CONFIG} ]]; then
			echo "[INFO] Backing up existing ${CLIENT_BETA_CONFIG} to ${CLIENT_BETA_CONFIG}.old"
			sudo cp "${CLIENT_BETA_CONFIG}" "${CLIENT_BETA_CONFIG}.orig"
		fi

	elif [[ ${action} == "restore" ]]; then
		echo "[INFO] Restoring old configuration"
		rm -f "${DECK_CONF}"
		# Restore client beta config or remove if it never existed
		if [[ -f "${CLIENT_BETA_CONFIG}.orig" ]]; then
			echo "[INFO] Old beta config found, restoring Steam Client beta"
			sudo bash -c "echo publicbeta > ${CLIENT_BETA_CONFIG}"
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
	local action=$1

	if [[ ${action} == "install" ]]; then
		if [[ ${VALID_GPU} == "true" ]]; then
			echo "[INFO] Found usable GPU for gamescope, enabling..."
			gamescope install
		else
			lightdm_fallback
		fi

	elif [[ ${action} == "uninstall" ]]; then
		# Remove configs"
		rm -f "${DECK_CONF}"
		gamescope uninstall
		config restore	

	elif [[ ${action} == "enable" ]]; then
		if [[ ${VALID_GPU} == "true" ]]; then
			echo "[INFO] Found usable GPU for gamescope, enabling..."
			gamescope enable
		else
			lightdm_fallback
		fi

	elif [[ ${action} == "disable" ]]; then
		if [[ ${VALID_GPU} == "true" ]]; then
			gamescope disable
		else
			lightdm_fallback
		fi

	fi

	echo "[INFO] Restarting Steam..."
	pkill steam

}


# Information display when no option is given
if [[ -z ${OPTION} ]]; then
	verify_status
fi

# Check for valid options
case "${OPTION}" in
	"help"|"--help"|"-h")
		show_help
		;;
	"--enable"|"--disable"|"--install"|"--uninstall")
		;;
		
	"--verify")
		verify_status
		;;
	*)
		echo "[ERROR] Failed to provid a valid option:"
		show_help
		exit 1
		;;
esac

main() {
	# Main handling routines	
	case "${OPTION}" in
		"--enable")
			config backup
			config install
			session enable
			;;
			
		"--disable")
			config restore
			session disable
			;;

		"--install")
			config backup
			config install
			session install
			;;

		"--uninstall")
			config uninstall
			session uninstall
			;;
	esac

	echo "[INFO] Done!"
}

# Start and log
main 2>&1 | tee /tmp/gamescope-switcher.log
echo "[INFO] Log: /tmp/gamescope-switcher.log"
