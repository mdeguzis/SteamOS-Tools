#!/bin/bash
# Description: Install, run, and manage Supermodel (Sega) emulator + roms

set -e

# Defaults
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/supermodel-mgr-${DATE}.log"
LINE="==========================================================="

function show_help() {
	cat<<-HELP_EOF
	--help|-h			Show this help page
	--install			Install supermodel

	HELP_EOF
	exit 0
}

function install_supermodel() {
	# Support ChimeraOS/Steam Deck
	if [[ -f "/usr/bin/frzr-unlock" ]]; then
		# ChimeraOS
		sudo frzr-unlock
	else
		sudo steamos-readonly disable
	fi

	# Deps
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
	mkdir -p ${HOME}/.config/supermodel/Config
	rsync -rav ${HOME}/src/supermodel/Config ~/.config/supermodel/Config/

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
	# TODO
}

# Start and log
main "$@" 2>&1 | tee "${LOG_FILE}"
echo "[INFO] Log: ${LOG_FILE}"

# Trim logs
find /tmp -name "supermodel-mgr-*" -mtime 14 -exec -delete \; 2>/dev/null

