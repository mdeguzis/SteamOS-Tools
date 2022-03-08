#!/bin/bash
# Description: Install/uninstall gamepad UI from Steam Deck

set -e 

cat<<-EOF
===========================================================
Steam Deck gamepadui installation script (experimental
===========================================================

EOF

OPTION=$1
CLIENT_BETA_CONFIG="${HOME}/.local/share/Steam/package/beta"
DECK_VER="steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d"
DECK_CONF="${HOME}/.config/environment.d/deckui.conf"
VGA_GPU=$(lspci -v | grep VGA)
VALID_GPU="false"
if echo "${VGA_GPU}" | grep -q "AMD"; then
	VALID_GPU="true"
fi

# Adjustable
RES_H="1080"
RES_W="1920"

if [[ -z ${OPTION} ]]; then
    echo "[ERROR] Missingi argument! One of: enable, disable, install, uninstall."
    exit 1
fi

mkdir -p ~/.config/environment.d

if [[ ${CLIENT_BETA_CONFIG} ]]; then
    echo "[INFO] Backing up existing ${CLIENT_BETA_CONFIG} to ${CLIENT_BETA_CONFIG}.old"
    sudo cp "${CLIENT_BETA_CONFIG}" "${CLIENT_BETA_CONFIG}.orig"
fi

# "publicbeta" is the original beta config if added previously
if [[ ${OPTION} == "enable" || ${OPTION} == "install" ]]; then
	# Add appropriate Steam client beta version
    sudo bash -c "echo ${DECK_VER} > ${CLIENT_BETA_CONFIG}"
	
	# Add deckui.conf
	cat <<-EOF >> "${DECK_CONF}"
	GAMESCOPECMD="gamescope -W ${RES_W} -H ${RES_H} --steam -f"
	STEAMCMD="steam -steamos -gamepadui"
	EOF
	
	if [[ ${OPTION} == "install" ]]; then
		if [[ ${VALID_GPU} == "true" ]]; then
			echo "[INFO] Valid GPU found, enabling usage of gamescope"
			read -erp "[INFO] Install gamescope with the gamepadUI for this session (y/N)?: " INSTALL_YN
			if [[ "${INSTALL_YN}" == "y" ]]; then
				sudo systemctl disable lightdm
				sudo systemctl enable gamescope@tty1
				echo "[INFO] On next reboot, gamescope (instead of lightdm) will be the default session"
				echo -n "[INFO] Press enter to start gamescope with the gamepadUI for this session (CTRL+C to cancel)..." && read -r
				sudo systemctl stop lightdm
				sudo systemctl start gamescope@tty
			else
				echo "[INFO] Aborting installation"
			fi
		else
			echo "[ERROR] Inappropriate GPU found for usage of gamescope. Falling back to lightdm and aborting permanent installation"
			sudo systemctl restart lightdm
		fi

	else
		echo "[WARN] Did not see an AMD GPU in use, falling back to lightdm only..."
		sudo systemctl restart lightdm
	fi
	
else
	# Remove configs"
	rm -f "${DECK_CONF}"
	
	# Restore client beta config or remove if it never existed
    if [[ -f "${CLIENT_BETA_CONFIG}" ]]; then
        sudo bash -c "echo publicbeta > ${CLIENT_BETA_CONFIG}"
    else
        rm -f "${CLIENT_BETA_CONFIG}"
    fi
fi

echo "[INFO] Done!"
