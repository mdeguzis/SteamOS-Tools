#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	install-ut4.sh
# Script Ver:	0.3.1
# Description:	Installs required packages, files for dhewm3, and facilitates
#		the install of the game.
##
# Usage:	./install-ut4.sh [OPTIONS]
# -------------------------------------------------------------------------------

# See:	
# https://forums.unrealtournament.com/showthread.php?14240-How-to-run-UT4-Alpha-build
# https://forums.unrealtournament.com/showthread.php?12011-Unreal-Tournament-Pre-Alpha-Playable-Build

# Archive source can also be generally noted from:
# https://aur.archlinux.org/packages/ut4/

OPTIONS="$1"

current_dir=$(pwd)
UT4_VER="3045522"
URL="https://s3.amazonaws.com/unrealtournament"
UT4_ZIP="UnrealTournament-Client-XAN-${UT4_VER}-Linux.zip"
UT4_DIR="${HOME}/ut4-linux/LinuxNoEditor"
UT4_BIN_DIR="${UT4_DIR}/LinuxNoEditor/Engine/Binaries/Linux/"
UT4_EXE="./UT4-Linux-Test UnrealTournament -SaveToUserDir"

UT4_SHORTCUT_TMP="${HOME}/UT4-alpha.desktop"
UT4_CLI_TEMP="${HOME}/ut4-alpha"

# See if we need to reset the directory
if [[ "${OPTIONS}" == "--reset" ]]; then

	echo -e "\n==> Resetting installation directory, please wait."
	sudo rm -rf "${UT4_DIR}"
	sudo rm -rf "/usr/share/applications/UT4-alpha.desktop"
fi


# Check for target dir
if [[ -d "${UT4_DIR}" ]]; then
	# DIR exists
	echo -e "\nUT4 Game directory found"
else
	mkdir -p "${UT4_DIR}"
fi

cd "${UT4_DIR}" || exit

#################################################
# Gather files
#################################################

# sourced from https://aur.archlinux.org/packages/ut4/

echo -e "\n==> Acquiring files...please wait\n"

sleep 2

echo -e "${UT4_ZIP}"
wget -O "${UT4_ZIP}" "${URL}/${UT4_ZIP}" -q -nc --show-progress

#################################################
# Setup
#################################################

unzip -o "${UT4_ZIP}"

# Mark main binary as executable
chmod +x "${UT4_BIN_DIR}/UT4-Linux-Test"

#################################################
# Post install configuration
#################################################

echo -e "\n==> Creating executable and desktop launcher"
sleep 2s

# copy UT4.png into Steam Pictures dir
sudo cp "${SCRIPTDIR}/artwork/games/ut4-alpha.png" "/usr/share/pixmaps"

cat <<-EOF> ${UT4_CLI_TMP}
#!/bin/bash
# execute ut4 alpha
cd ${UT4_BIN_DIR}
${UT4_EXE}
EOF

cat <<-EOF> ${UT4_shortcut_tmp}
[Desktop Entry]
Name=UT4 alpha
Comment=Launcher for UT4 Tournament Alpha
Exec=/usr/bin/ut4-alpha
Icon=/usr/share/pixmaps/ut4-alpha.png
Terminal=false
Type=Application
Categories=Game;
MimeType=x-scheme-handler/steam;
EOF

# mark exec
chmod +x ${UT4_CLI_TEMP}

# move tmp var files into target locations
sudo mv ${UT4_SHORTCUT_TMP}  "/usr/share/applications"
sudo mv ${UT4_CLI_TMP} "/usr/bin"

#################################################
# Cleanup
#################################################

# return to previous dir
cd ${CURRENT_DIR} || exit

cat <<-EOF

-----------------------------------------------------------------------
Summary
-----------------------------------------------------------------------
Installation is finished. You can either run 'UT4-alpha' from
the command line, or start 'UT4 aplha' from you applications directory.
The launcher should show up as a non-Steam game as well in SteamOS BPM.
EOF
