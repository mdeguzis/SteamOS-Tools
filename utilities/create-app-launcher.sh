#!/bin/bash
# -------------------------------------------------------------------------------
# Author:       	Michael DeGuzis
# Git:	        	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	    create-app-launcher.sh
# Script Ver:     0.1.1
# Description:	  Setup custom shortcuts
#
# See:            
#
# -------------------------------------------------------------------------------

scriptdir=${PWD}

echo -e "\n==> Creating non-Steam shortcut"
sleep 0.5s

read -erp "Name of shortcut: " NAME_TEMP
read -erp "Set a generic name / comment: " GENERIC_TEMP
read -erp "Icon location: " ICON_TEMP
read -erp "Executable location: " EXEC_TEMP

# copy in template file
sudo cp ../cfgs/desktop-files/template.desktop /usr/share/applications

# Remove any spaces in name for TARGET_NAME
TARGET_NAME=$(echo $NAME_TEMP | sed "s| |-|g")

# Modify shortcut
cd /usr/share/applications
mv template.desktop "${TARGET_NAME}"

SHORTCUT="/usr/share/applications/${TARGET_NAME}.desktop"

sudo sed -i "s|EXEC_TEMP|$EXEC_TEMP|g" "${SHORTCUT}"
sudo sed -i "s|NAME_TEMP|$NAME_TEMP|g" "${SHORTCUT}"
sudo sed -i "s|ICON_TEMP|$ICON_TEMP|g" "${SHORTCUT}"

cat<<-EOF

==INFO==
The shorcut/application should now be selectible in BPM.
If it is _not_, check all paths are valid in the .desktop file.

EOF
