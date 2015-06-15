#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	    	Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 		add-wine-game.sh
# Script Ver: 		0.1.1
# Description:		Launch Windows game using Crossover / Wine
#
# See:            http://steamcommunity.com/groups/steamuniverse/
#                 discussions/1/618463738398679174/
#
# Usage:		      TODO
# ------------------------------------------------------------------------

################################
# WARNING!!!
################################
# BEING TESTED / WORKED ON
# DO NOT USE
################################

# vars
GAME_ID="default"
GAME_LAUNCHER_TMP="default"
WG_DIR="/home/steam/wgstarts"
WINE_LAUNCH_DIR="/home/wine/wingame"

# create WG_DIR DIR if it does not exist
# "wine game starts"

# create game launch script

# prompt for game name, store to 'game_id'

# set game launcher name based on game id
GAME_LAUNCHER_TMP="${GAME_ID}-Launcher.sh"

# echo script text into /home/steam/wgstarts
cat <<-EOF > ${WG_DIR}/${GAME_LAUNCHER_TMP}
install -m 777 /dev/null /tmp/wgname
echo $GAME_ID >> /tmp/wgname
feh -F -b -x --auto-zoom /usr/share/backgrounds/cog.png &
/usr/bin/switchtowine.sh
sleep 4
killall feh
EOF

# create desktop file from skel

# create actual wine launcher under /home/steam/wingame
# this may exist, I need to test first with a Crossover install

cat <<-EOF > ${WINE_LAUNCH_DIR}${GAME_LAUNCHER_TMP}
#!/bin/bsh
sh /home/wine/shutdown-wine-game.sh &
exec "/opt/cxoffice/bin/wine" --bottle "Steam" --check --wait-children --start "/home/wine/.cxoffice/Steam/drive_c/users/crossover/Desktop/Leviathan Warships.url" "$@"
killall steam.exe
EOF

