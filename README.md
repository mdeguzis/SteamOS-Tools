## SteamOS-Tools
Tools and scripts for SteamOS.

## Usage

To clone this repository to your local computer, you will need the `git` software package. After this is installed, clone SteamOS-Tools with:

```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
```

Please refer to the readme files in the docs/ folder in this reppository. Normal script execution, sans arguments, goes a little bit like:

```
./script-name.sh
```

## Contents
* cfgs/ - various configuration files, including package lists for Debian software installations.
* docs/ - readme files for each script.
* extra/ - various extra scripts
* scriptmodules/ - plugable bash modules / routines for any of the below scripts.
* README.md - This file.
* add-debian-repos.sh - adds debian repositories for installing Debian Wheezy software.
* build-test-chroot.sh - build a Debian or SteamOS jail for testing **[in progress]**
* buld-test-docker.sh - build a Debian or SteamOS package for testing.
* desktop-software.sh - script to install custom and bulk Debian desktop software packages. Please see the readme file in docs/ for the full listing of options.
* steamos-stats.sh - displays useful stats while gaming over SSH from another device.
* pair-ps3-bluetooth.sh - pairs your PS# blueooth controllers to a supported receiver.

## Wiki
- In time I hope to maintain a colletion of useful articles or links to Steamcommunity Guides that still work, currate them and other such things*.

* TODO (hey I have other cool stuff, ya know, to do).

## Pull requests / suggestions
Please submit any issues / suggestions to the issues tracker on the right hand side of this page
or any corrections (with justification) as a Pull Request.

## Troubleshooting
Most scripts in the main folder of the repository write stdout and stderr to `log.txt` in the current directory after completion. Please check this file before submitting any issues or pull requests.
