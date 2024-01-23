#!/bin/bash
# Description: Install, run, and manage Supermodel (Sega) emulator + roms

set -e

# Defaults
DATE=$(date +%Y%m%d-%H%M%S)
GIT_ROOT=$(git rev-parse --show-toplevel)
LOG_FILE="/tmp/supermodel-mgr-${DATE}.log"
LINE="==========================================================="

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--install			Install supermodel
	--configure-input|-c		Pre-configure inputs (Thank you https://github.com/WarpedPolygon!)
	--add-game			Add game desktop file for Steam
	--remote-game			Remove game desktop file for Steam
	--game-name			Set name of game to add/remove
	--game-zip			Set zip location for game to add/remove

	HELP_EOF
	exit 0
}

function install_supermodel() {
	# use the Flatpak (much safer install
	# https://gitlab.com/es-de/emulationstation-de/-/blob/master/USERGUIDE.md#arcade-and-neo-geo
	# https://flathub.org/apps/com.supermodel3.Supermodel
	OS_TYPE=$1
	
	# Support ChimeraOS/Steam Deck
	if [[ "${OS_TYPE}" == "ChimeraOS" ]]; then
		# ChimeraOS
		# For some reason, the flatpak doesn't like to run on ChimeraOS (yet)
		# Error: OpenGL initialization failed: unknown error
		INSTALL_TYPE="ChimeraOS"
		sudo frzr-unlock

		echo -e "\n[INFO] Initializing and refreshing keys, please wait..."
		sudo pacman -Syy
		sudo pacman -S archlinux-keyring --noconfirm
		sudo pacman-key --init
		sudo pacman-key --populate archlinux

		# If this fails, regenerate mirrors with the curl command and upgrade keyring
		# 	https://wiki.archlinux.org/title/mirrors
		# 	sudo pacman -Sy archlinux-keyring --noconfirm
		# This also manifests as getting install errors such as:
		# 	error: pkgconf: signature from "Johannes Löthberg <johannes@kyriasis.com>" is marginal trust
		sudo pacman -Sy sdl2 sdl2_net devtools base-devel --noconfirm

		# Clone
		echo -e "\n[INFO] Building and installing supermodel"
		mkdir -p ${HOME}/src
		if [[ ! -d "${HOME}/src/supermodel" ]]; then
			git clone https://github.com/trzy/Supermodel ~/src/supermodel
		else
			git -C "${HOME}/src/supermodel" pull
		fi
		cd "${HOME}/src/supermodel"
		make -f Makefiles/Makefile.UNIX NET_BOARD=1

		# When built, we need to execute this link from the src root
		sudo ln -sfv $(readlink -f bin/supermodel) /usr/bin/supermodel
	else
		flatpak install --user com.supermodel3.Supermodel -y
	fi

	echo -e "\nBasic usage: https://www.supermodel3.com/Usage.html"
}

main() {
	cat<<-EOF
	${LINE}
	Supermodel (Sega) manager
	${LINE}
	EOF

	while :; do
		case $1 in
			--install|-i)
				INSTALL="true"
				;;

			--add-game|-a)
				ADD_GAME="true"
				;;

			--configure-input|-p)
				CONFIGURE_INPUT="true"
				;;

			--game-name|-n)
				if [[ -n $2 ]]; then
					GAME_NAME="$2"
				else
					echo "[ERROR] An argument must be passed!"
					exit 1
				fi
				shift
				;;

			--game-zip|-z)
				if [[ -n $2 ]]; then
					GAME_ZIP="$2"
				else
					echo "[ERROR] An argument must be passed!"
					exit 1
				fi
				shift
				;;

			--remove-game)
				REMOVE_GAME="true"
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

	if [[ -f "/usr/bin/frzr-unlock" ]]; then
		OS_TYPE="ChimeraOS"
	else
		OS_TYPE="SteamDeck"
	fi
	echo -e "[INFO] Install type: ${OS_TYPE}"

	if [[ ${INSTALL} == "true" ]]; then
		install_supermodel ${OS_TYPE}
	fi	

	# Add desktop files for games
	# Set max resolution from available modes
	# Using the modes file, it seems to be backwards:
	# 	Steam Deck: 800x1280 
	DEVICE_RES_X=$(cat /sys/class/drm/*/modes | head -n 1 | awk -F'x' '{print $2}')
	DEVICE_RES_Y=$(cat /sys/class/drm/*/modes | head -n 1 | awk -F'x' '{print $1}')
	DEVICE_RES=$(echo "${DEVICE_RES_X},${DEVICE_RES_Y}")

	# Set vars
	if [[ ${ADD_GAME} == "true" ]]; then
		GAME_BASENAME=$(basename ${GAME_ZIP} | sed 's/\.zip//')
		if [[ -z ${GAME_NAME} || -z ${GAME_ZIP} ]]; then
			echo "[ERROR] Please provide the game name and game zip args!"
			exit 1
		fi

		# Verify paths
		if [[ ! -f ${GAME_ZIP} ]]; then
			echo "[ERROR] Could not locate game zip at path: '${GAME_ZIP}'!"
			exit 1
		fi

		# Copy desktop file with absolute path to game zip
		cp -v "${GIT_ROOT}/cfgs/desktop-files/supermodel-template.desktop" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"

		# Update values
		sed -i "s|GAME_NAME|${GAME_NAME}|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		sed -i "s|GAME_ZIP|${GAME_ZIP}|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		sed -i "s|DEVICE_RES|${DEVICE_RES}|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		sed -i "s|START_PATH|${HOME}/src/supermodel|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		if [[ "${OS_TYPE}" == "ChimeraOS" ]]; then
			echo "[INFO] Using built binary"
			sed -i "s|SUPERMODEL_BIN|/usr/bin/supermodel|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		else
			echo "[INFO] Using flatpak"
			sed -i "s|SUPERMODEL_BIN|/usr/bin/flatpak run com.supermodel3.Supermodel|g" "${HOME}/.local/share/applications/supermodel-${GAME_BASENAME}.desktop"
		fi
	fi

	# Configure input?
	if [[ ${CONFIGURE_INPUT} == "true" ]]; then
		cat<<-EOF

		Configure input:

		1) xinput
		2) dinput

		EOF
		read -erp "Choice: " INPUT_CHOICE
		if [[ ${INPUT_CHOICE} == "1" ]]; then
			cp -v "${GIT_ROOT}/cfgs/supermodel3/xinput/Supermodel.ini" "${HOME}/src/supermodel/Config/"
		elif [[ ${INPUT_CHOICE} == "2" ]]; then
			cp -v "${GIT_ROOT}/cfgs/supermodel3/dinput/Supermodel.ini" "${HOME}/src/supermodel/Config/"
		else
			echo "[ERROR] Invalid choice!"
			exit 1
		fi

		mkdir -p "${HOME}/src/supermodel/NVRAM"
		cp -r "${GIT_ROOT}/cfgs/supermodel3/nvram/" "${HOME}/src/supermodel/NVRAM/"

	fi

}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"
echo "[INFO] Looking for notes on how to pre-configure controls for your gamepad? See cfgs/supermodel3/README.md"

# Trim logs
find /tmp -name "supermodel-mgr-*" -mtime 14 -exec -delete \; 2>/dev/null

