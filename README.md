<img src="https://github.com/ProfessorKaos64/SteamOS-Tools/raw/brewmaster/artwork/SteamOS-Tools.png" width=100%/>

# SteamOS-Tools

Version 1.7.2

Tools and scripts for SteamOS. Be sure to check out the [Upcoming features](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Development-and-Features#upcoming-planned-features) subsection on the wiki for the latest developments! For those of you that wish to contribute, suggest, or otherwise correct code, please first read the [Development and Feautres](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Development-and-Features) wiki page. Code corrections, additions, and all other suggestions can be made to the [issus](https://github.com/ProfessorKaos64/SteamOS-Tools/issues) tracker.

All operations are tested against official Valve releases only.

For the latest change details, please see the commits page, orchangelog.md for overall change details.

# Warning

Please take time to read the [disclaimer](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/alchemist/disclaimer.md).

# Wiki and FAQ

Please refer to the [wiki](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki), located to your right in this repository for all supplemental information and instructions. A direct link to the FAQ is [here](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/FAQ). Information for installations, as well as much more, is located within. If there is a page missing, or information you wish me to add, please let me know via an issues ticket.

# Hosted packages

There is now a Debian personal repository hosted at packages.libregeek.org. Be sure to check out the "hosted packages" section below! The wiki entry also contains repository information if you should wish to add the repository manually.

[SteamoS-Tools Repository](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/SteamOS-Tools-Repository)

# Usage / Installation

Please make sue you have enabled desktop mode (Settings > Interface > Enable access to the Linux desktop), and aset your password for the dekstop user with `passwd`.

To clone this repository to your local computer, you will need the `git` software package to clone the repository. The command is included below in the first line below if you do not know it.
```
sudo apt-get install git
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools/
```

To update your local copy of files:
```
cd SteamOS-Tools/
git pull
```

There is also a testing branch for this repository, but I advise against using it.

Normal script execution, sans arguments, goes a little bit like:

```
./script-name.sh
```

## Contents
* artwork - banners and various images/artwork for SteamOS.
* cfgs/ - various configuration files, including package lists for Debian software installations.
* docs/ - readme files for each script.
* ext-game-installers/ - Game installers for games outside Steam (e.g. GZDoom)
* extra/ - various extra scripts
* game-fixes - a location to store some small deployable fixes for games.
* scriptmodules/ - plugable bash modules / routines for any of the below scripts. Scripts for packages and more (including Netflix!)
* utilities/ - various scripts to handle small parts of the SteamOS-Tools repository (plugable objects) and standalone tools for use.
* README.md - This file.
* add-debian-repos.sh - adds debian repositories for installing Debian software.
* desktop-software.sh - script to install custom and bulk Debian desktop software packages, as well as special additional packages/utilities, such as gameplay recording, "web apps," and more. Please see the readme file in docs/ for the full listing of options.
* disclaimer.md - safety warnings for this repository.

# Wiki
- In time I hope to maintain a colletion of useful articles or links to Steamcommunity Guides that still work, currate them and other such things*.

# Video demonstrations / tutorials

* [SteamOS-Tools introductory video](https://youtu.be/h-gdPWjZlb4)
* [Retroarch demonstration video (courtesy of Ryochan7)](https://www.youtube.com/watch?v=4wcIWG-WsXY)

# Branches
There are four main branches at the moment

`alchemist`  
Alchemist branch. Due to Brewmaster being usable now, this branch is not as up to date.  
`brewmaster`  
Brewmaster branch. Default branch for repository.  
`testing-a`  
Branch where new scripts are made, larger alterations to existing ones implemented, and more for alchemist.  
`testing-b`    
Branch where new scripts are made, larger alterations to existing ones implemented, and more for brewmaster.  

# Pull requests / suggestions
Please submit any issues / suggestions to the issues tracker on the right hand side of this page
or any corrections (with justification) as a Pull Request. Have a cool script or method to enhance SteamOS? Send it over! Your name will be added to the script header and the contributing.md file. 

# Troubleshooting
Most scripts in the main folder of the repository write stdout and stderr to `log.txt` in the current directory after completion. Please check this file before submitting any issues or pull requests.
