## About
***
This script aids in installing basic, extra, emulation,or custom 
sets of Debian software to SteamOS. 

The package install loop checks all packages one by one if they are installed first. 
If any given pkg is not, it then checks for a prefix !broken! in any dynamically called list
(basic,extra,emulation, and so on). Pkg names marked !broken! are skipped and the rest are attempted to be installed. 

*The installations are attemped in the following order:*

1. Automatic based on /apt/preferences priority / Alchemist
2. Wheezy repository
3. Wheezy-backports repository

## Usage

You can run the utility using the follwing options:

```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
./desktop-software.sh [option] [type]
```
**Options:** [install|uninstall|list|test|check]    
**Type:** [basic|extra|emulation|<pkg_name>]  
**Type (extra):** [plex]   

***
#### Options
***
**install:**   
installs software based on type desired  
**uninstall:**   
uninstalls software based on type installed already  
**list:**   
lists softare pacakges in each install group  
**test:**     
perform a dry-run installation of <pkg>  
**check:**     
Run quick check on package(s)

***
#### Types
***
**basic:**  
installs basic Debian software (based on [Distrowatch](http://distrowatch.com/table.php?distribution=debian))  
**extra:**  
installs extra softare based on feedback and personal preference  
**emulation: [in-progress, debs need built]**        
retroarch and associated emulators.      
**emulation-src: [in-progress]**            
Installs prerequisite packages for compiling emulation packages from source and then compiles emulators packages from source (will take some time to install).       
**emulation-src-deps:**          
packages required for [building](https://wiki.debian.org/CreatePackageFromPPA) Debian packages from emulator source code (e.g. ppa:libretro/stable).  

**`<pkg_name>:`**      
installs package(s) specifified from Alchemist/Wheezy. You can speciy any number of space-delimited packages such as "pkg1 pkg2 pkg3".  

***
#### Extra Types available
***
- [Plex]: Kicks off an automated script to install plexhometheatre
- [firefox]: sourced from Linux Mint LMDE 2
- [Xbox-Bindings]: the amazing set of controller bindings from [Sharkwouter](https://github.com/sharkwouter) and his [VaporOS 2](https://steamcommunity.com/groups/steamuniverse/discussions/1/612823460253620427/) SteamOS variant

***
## Emulation type Warning
***
Installing retroarch and the emulators takes a very long time!. Please be aware of this before attempting the installation. Installing prerequisite packages, compiling Retorarch, and it's emulators, is time-intensive. This component of the script is very much *still in progress!* 

I will do my best to reduce overhead on this installation piece as much as possible.

### Please note
***

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository here. `sudo` access is required for package installations. All code is available for review.
