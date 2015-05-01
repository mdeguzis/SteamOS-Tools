<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

  - [About](#about)
- [Usage](#usage)
  - [Options](#options)
  - [Types](#types)
  - [Extra Types available](#extra-types-available)
  - [Warning regarding the emulation-src type](#warning-regarding-the-emulation-src-type)
  - [Post build instructions for Retroarch](#post-build-instructions-for-retroarch)
  - [Please note](#please-note)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

### About
***
This script aids in installing basic, extra, emulation,or custom 
sets of Debian software to SteamOS. 

The package install loop checks all packages one by one if they are installed first. 
If any given pkg is not, it then checks for a prefix !broken! in any dynamically called list
(basic,extra,emulation, and so on). Pkg names marked !broken! are skipped and the rest are attempted to be installed. 

*The installations are attemped in the following order:*

1. Automatic based on /apt/preferences.d/{repo} priority / Alchemist
2. Wheezy repository
3. Wheezy-backports repository

#####Notes regarding apt-pinning / apt-preferences 
Apt-pinning is implemented in the `add-debian-repos.sh` script to give Steam and SteamOS release types highest priority. Beneath this, Debian and Debian-Backports are given a much lower priority. For details on current pin levels, please reference [these](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/master/add-debian-repos.sh#L111) lines of code. If the line number is off, the section is titled "# Create and add required text to preferences file". 

Apt-pin preferences are subject to change. Ideally, the testing branch will be tested properly before hand, and package policy checked with `apt-cache policy` as well. Please submit any suggestions or corrections anyone feels should be made as a pull request.

## Usage

You can run the utility using the follwing options:

```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
./desktop-software.sh [option] [type]
```

***
### Options
***
`install`     
installs software based on type desired 

`uninstall`     
uninstalls software based on type installed already  

`list`     
lists softare pacakges in each install group  

`test`       
perform a dry-run installation of package(s) 

`check`         
Run quick check on package(s)  

***
### Types
***
`basic`    
installs basic Debian software (based on [Distrowatch](http://distrowatch.com/table.php?distribution=debian))  

`extra`  
installs extra softare based on feedback and personal preference  

`emulation`          
retroarch and associated emulators. (in-progress, debs need built)  

`emulation-src`  
Installs prerequisite packages for compiling emulation packages from source and then compiles and builds libretro packages from source (will take some time to install). See the [script header](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/master/scriptmodules/emu-from-source.shinc) for the latest test stats on build time.  (basic routines are done, some work left)     

`emulation-src-deps`            
Packages required for [building](https://wiki.debian.org/CreatePackageFromPPA) Debian packages from emulator source code (e.g. ppa:libretro/stable). (in-progress)  

`upnp-dlna`            
packages required UPnP / DLNA streaming from a mobile device (experimental / in-progres)   

`<pkg_name>`     
installs package(s) specifified from Alchemist/Wheezy. You can specify any number of space-delimited packages such as "pkg1 pkg2 pkg3".  

`games-pkg`           
Installs a some Linux games that you can then add to Steam via the "add non-Steam game" option.

`gaming-tools`         
Installs some gaming tools, such as jstest, WINE, and more.
***
### Extra Types available
***
`kodi`      
Kicks off an automated script to install Kodi, as provided by the [SteamOS Kodi repository](http://forum.kodi.tv/showthread.php?tid=197422)  

`firefox`      
sourced from Linux Mint LMDE 2.    

`plex`      
Kicks off an automated script to install plexhometheatre.  

`nodejs`      
Kicks off an automated script to install Node JS and NPM.  

`xbox-bindings`      
Installs the nice set of controller bindings from [Sharkwouter](https://github.com/sharkwouter) and his [VaporOS 2](https://steamcommunity.com/groups/steamuniverse/discussions/1/612823460253620427/) SteamOS variant

***
### Warning regarding the emulation-src type
***
Installing retroarch and the emulators takes a very long time!. Please be aware of this before attempting the installation. Installing prerequisite packages, building Retorarch, and the libretro cores, is time-intensive. The MAME and MESS cores take up most of this time.

Statistics:    
**Test Build:** - (pre-fetched, build) 57 minutes. Intel Core 2 Quad Q9560, 8 GB DDR2, 7200 RPM HDD, 15 Mb/s WLAN  
**Test Build:** - (fetch, build) 86.36 minutes. Intel Core 2 Quad Q9560, 8 GB DDR2, 7200 RPM HDD, 15 Mb/s LAN

***
### Post build instructions for Retroarch
***

Please see [Retroarch-info.md](https://github.com/ProfessorKaos64/SteamOS-Tools/edit/testing/docs/retroarch-info.md) for this information.

### Please note
***

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository here. `sudo` access is required for package installations. All code is available for review.
