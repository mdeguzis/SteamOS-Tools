<img src="https://github.com/mdeguzis/SteamOS-Tools/raw/master/artwork/SteamOS-Tools.png" width=100%/>

# SteamOS-Tools
***

SteamOS-Tools is a personal collection of scripts and utilities for enhancing an Arch-based SteamOS 3.x install (Valve's Steam Deck OS, and Arch-based derivatives such as Bazzite) beyond the "stock" experience: emulator/AppImage management, Flatpak install/update automation with Steam library shortcut + SteamGridDB artwork integration, ProtonDB and MangoHud tooling, controller and peripheral helpers, and more.

This repository previously targeted **SteamOS Brewmaster/Alchemist** (SteamOS 1.x/2.x, Debian-based) and hosted a Debian package repository. That entire apt/dpkg-era toolchain (`configure-repos.sh`, the `packages.libregeek.org` package repo, `scriptmodules/`, `reprepro`, and related scripts) has been retired now that SteamOS itself has moved to an Arch base. Only Arch/Flatpak/AppImage-oriented tooling remains.

All operations are tested against official Valve releases and current Arch-based SteamOS derivatives.

# Warning
***

Please take time to read the [disclaimer](disclaimer.md) before running anything from this repository.

# SteamOS-Tools Usage / Installation
***

Ensure `git` is installed via your distribution's package manager, then clone the repository:

```
git clone https://github.com/mdeguzis/SteamOS-Tools
cd SteamOS-Tools/
```

Normal script execution, sans arguments, goes a little bit like:

```
./script-name.sh
```

# Updating
***

To update your local copy of files for this repository:

```
cd SteamOS-Tools/
git pull
```

# Contents
***

* artwork/ - Banners and various images/artwork for SteamOS.
* cfgs/ - Various configuration files for supported utilities (wine, retroarch, samba, systemd units, etc).
* docs/ - Documentation for tools in this repository.
* ext-installers/ - Installers for games and add-ons outside Steam.
* extra/ - Various extra scripts and reference notes.
* game-fixes/ - A location to store some small deployable fixes for games.
* launchers/ - Script launchers for various software.
* SteamOS-3.x/ - Historical research notes from early SteamOS 3.x/ChimeraOS-era work.
* utilities/ - Scripts to handle small parts of the SteamOS-Tools repository (plugable objects), build scripts, and standalone tools for use.
* README.md - This file.
* AUTHORS.md - Contributions, attributions, and more.
* LICENCE.md - License for this repository.
* contributing.md - Guidelines for repository contributions.
* disclaimer.md - Safety warnings for this repository.

# Requests / Suggestions / Contributions
***

Please submit any issues / suggestions to the issues tracker on the right hand side of this page, or any corrections (with justification) as a Pull Request. Have a cool script or method to enhance an Arch-based SteamOS install? Send it over! Your name will be added to the script header and the AUTHORS.md file.

# Troubleshooting
***

You can run `utilities/protondb-systeminfo-tool.sh` from within the SteamOS-Tools repository directory to collect system information that can help diagnose a reported issue. Most scripts in this repository write stdout and stderr to `log.txt` in the current directory after completion; please check this file before submitting any issues or pull requests.
