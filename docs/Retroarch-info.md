<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [General](#general)
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

### Source build information

Below you can find related information pertaining to building Retroarch/Libretro from source. This will only include items outside the automatic build script invoked by `desktop-software.sh`.

#####Testing machine specifications
===

**SteamOS-Test**  
* CPU: Intel Core 2 Quad Q9550
* RAM: 6 GB DDR2
* HDD: Seagate 7400 RPM
* GPU: Nvidia GT 640

**SteamOS Primary**  
* CPU: Intel Core i5 2500k
* RAM: 8 GB DDR3
* HDD: Seagate SSHD
* GPU: Nvidia GTX 770 SC

**SteamOS Secondary**  
* CPU: Intel Core i5 2500k
* RAM: 16 GB DDR3
* HDD: Intel SSD
* GPU: Nvidia GTX 550 Ti

####Latest Testing Results
===

**Host: SteamOS-Test**  
Date: 20150429  
Runtime: 86.25 minutes  
Pass: 48, Fail: 1  
Cores failed: gw  
Already fetched: [no]  

**Host: SteamOS**  
Date: 20150429    
Runtime:   
Pass:   
Cores failed:  
Already fetched:    

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
