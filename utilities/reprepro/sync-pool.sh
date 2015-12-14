#!/bin/bash

###################
# Main processing
###################

# move incoming to old folder. suppress output if empty
mv incoming/*.* ../incoming-old 2> /dev/null

# remove packages older than 3 months to save space
find ../incoming-old -mtime +90 -exec rm {} \;

# sync remote
rsync -avz --delete /home/mikeyd/packaging/SteamOS-Tools/ thelinu2@libregeek.org:/home2/thelinu2/public_html/packages/SteamOS-Tools

###################
# sync pools
###################

# remove all packages from the testing pool
# reprepro removefilter brewmaster_testing 'Section'

###################
# Advanced actions
###################

# remove all pacakges matching name
# reprepro list brewmaster | grep libretro | cut -d " " -f 2 | xargs reprepro remove brewmaster {}
