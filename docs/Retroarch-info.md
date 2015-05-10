<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [General](#general)
- [BIOS](#bios)
- [Disc Images](#discimages)
- [Input (General)](#input-general)
- [Input (Xbox 360 Controllers)](#input-xbox-360-controllers)
- [Input (Sony PS3 Controllers)](#input-sony-ps3-controllers)
- [Tested / known working cores](#tested--known-working-cores)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

### General
***
After running the emulation-src type, currently you must still perform the following as of 20150427:

1. Add "Retroarch-Src" as a "non-Steam" game using the "+" icon on the Libary section of SteamOS
2. Configure your joypad via Retroarch > Settings > Input Settings (use bind all to configure all buttons at once)
3. Transfer any ROMs you had on your system, into appropriate folder structures under `/home/steam/ROMs`

***
### General
***
Since the "system" directory of Retroarch is pre-configured to `/home/<user>/ROMs`, you'll want to also dump your BOIS files in this location as well.

#####PSX/PS1 BIOS Files

Mednafen is very picky about which BIOS to use. The ones that you might need are:

* scph5500.bin
* scph5501.bin
* scph5502.bin

Copy this file to the `$HOME/ROMs` directory of the user you are working with. Most commonly this is `/home/steam/ROMs`. If you can't find one of these, just rename the respective scph100x.bin BIOS (such as scph1001.bin) to scph550x.bin (such as scph5501.bin) and it will take it. 

***
### Disc Images
***

Mednafen requires you to load games through CUE sheets. Ensure that the CUE sheet is properly set up in order for the game to run. See the Cue sheet (.cue) for more.

***
### Input (General)
***
Please take note of the following general modifications

* Save state: Left-thumbstick click (L3)
* Load state: Right-thumbstick click (R3)
* Show Retroarch menue: back/select
* Exit Game: Enter menu, choose "Quit Retroarch"
 
Please note: The center button of either the Sony or Microsoft controllers is not ideal for opening the Retroarch menu or quitting Retroarch. Steam Big Picture Mode / SteamOS uses this button by default to bring up the Steam overlay.

***
### Input (Xbox 360 Controllers)
***
The Xbox controllers are mapped as per the onscreen input directions in Retroarch > Settings > Input Settings.

***
### Input (Sony PS3 Controllers)
***

***
### Tested / known working cores
***
You can find a list of cores tested with games already [here](https://github.com/ProfessorKaos64/SteamOS-Tools/edit/testing/docs/Retroarch-Testing-Checklist.md)
