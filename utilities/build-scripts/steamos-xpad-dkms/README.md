# steamos-xpad-dkms
Valve patched xpad driver

# Purpose
Rebuild patched xpad driver to maintain a fresh up to date package for non-SteamOS users.
	 
To build manually:
======================

TODO

# Source
https://raw.github.com/ValveSoftware/steamos_kernel/$COMMIT/drivers/input/joystick/xpad.c

xpad.c in the root directly is replaced at build time with the desired commit.

Please see:  
https://github.com/ProfessorKaos64/SteamOS-Tools/blob/brewmaster/utilities/build-scripts/build-steamos-xpad-dkms.sh
