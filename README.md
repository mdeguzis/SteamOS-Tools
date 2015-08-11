## SteamOS-Tools
Tools and scripts for SteamOS.

## Warning

Please take time to read the [disclaimer](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/alchemist/disclaimer.md).

## Usage

To clone this repository to your local computer, you will need the `git` software package. After this is installed, clone SteamOS-Tools with:
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools/
```

To update your local copy of files:
```
cd SteamOS-Tools/
git pull
```

There is also a testing branch for this repository, but I advise against using it.

Please refer to the readme files in the docs/ folder in this reppository. Normal script execution, sans arguments, goes a little bit like:

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
  * build-deb-from-ppa.sh - attempts to build a Debian package from a PPA repository.
  * build-deb-from-src.sh - attempts to build a Debian package from a git source tree.
  * build-test-chroot.sh - build a Debian or SteamOS jail for testing **[in progress]**
  * buld-test-docker.sh - create a docker container for testing.
  * gpg_import.sh - import GPG keys (used internally).
  * pair-ps3-bluetooth.sh - pairs your PS3 blueooth controllers to a supported receiver.
  * ssh-rom-transfer.sh - transfer ROMs over SSH to a remote computer.
  * steamos-stats.sh - displays useful stats while gaming over SSH from another device.
* README.md - This file.
* add-debian-repos.sh - adds debian repositories for installing Debian wheezy software.
* desktop-software.sh - script to install custom and bulk Debian desktop software packages, as well as special additional packages/utilities, such as gameplay recording, "web apps," and more. Please see the readme file in docs/ for the full listing of options.
* disclaimer.md - safety warnings for this repository.

## Wiki
- In time I hope to maintain a colletion of useful articles or links to Steamcommunity Guides that still work, currate them and other such things*.

## Video demonstrations / tutorials

* Coming soon

## Branches
There are three main branches at the moment

`alchemist`  
Default branch - "stable" work that gets PRs, fixes, priority over all other branches.  
`brewmaster`  
Now that Jessie is stable, evaluation of the Brewmaster SteamOS release and packages is underway. **Not** recommended for use.  
`brewmaster-beta`  
Based on the brewmaster-beta repo for SteamOS "V2". **Not** recommended for use.  This is where the most active changes will occur until Brewmaster becomes more stable.  
`testing`  
Branch where new scripts are made, larger alterations to existing ones implemented, and more.  

## Pull requests / suggestions
Please submit any issues / suggestions to the issues tracker on the right hand side of this page
or any corrections (with justification) as a Pull Request. Have a cool script or method to enhance SteamOS? Send it over! Your name will be added to the script header and the contributing.md file. 

## Troubleshooting
Most scripts in the main folder of the repository write stdout and stderr to `log.txt` in the current directory after completion. Please check this file before submitting any issues or pull requests.
