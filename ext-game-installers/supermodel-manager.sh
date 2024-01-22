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
	flatpak install --user com.supermodel3.Supermodel -y

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

	# Do we need to buidl
	if [[ ${INSTALL} == "true" ]]; then
		install_supermodel
	fi	

	# Add desktop files for games
	# Set max resolution from available modes
	DEVICE_RES=$(cat /sys/class/drm/*/modes | head -n 1)

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
	fi

}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"

# Trim logs
find /tmp -name "supermodel-mgr-*" -mtime 14 -exec -delete \; 2>/dev/null

