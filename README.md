<img src="https://github.com/mdeguzis/SteamOS-Tools/raw/master/artwork/SteamOS-Tools.png" width=100%/>

# SteamOS-Tools
***

[![CI](https://github.com/mdeguzis/SteamOS-Tools/actions/workflows/ci.yml/badge.svg)](https://github.com/mdeguzis/SteamOS-Tools/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/steamos-tools)](https://pypi.org/project/steamos-tools/)
[![Python versions](https://img.shields.io/pypi/pyversions/steamos-tools)](https://pypi.org/project/steamos-tools/)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENCE.md)

SteamOS-Tools is a personal collection of scripts and utilities for enhancing an Arch-based SteamOS 3.x install (Valve's Steam Deck OS, and Arch-based derivatives such as Bazzite) beyond the "stock" experience: emulator/AppImage management, Flatpak install/update automation with Steam library shortcut + SteamGridDB artwork integration, ProtonDB and MangoHud tooling, controller and peripheral helpers, and more.

This repository previously targeted **SteamOS Brewmaster/Alchemist** (SteamOS 1.x/2.x, Debian-based) and hosted a Debian package repository. That entire apt/dpkg-era toolchain has been retired now that SteamOS itself has moved to an Arch base. Only Arch/Flatpak/AppImage-oriented tooling remains.

All operations are tested against official Valve releases and current Arch-based SteamOS derivatives.

## In-progress: consolidating into a Python CLI
***

The bash scripts under `utilities/`, `ext-installers/`, and `game-fixes/` are being consolidated into a single `steamos-tools` Python package with shared libraries, a real test suite, and CI/CD. Not everything has been converted yet -- see the open tracking issue for what's moved over and what's still a standalone script. Converted tools are removed from their old script location once ported; anything not yet listed below is still a plain bash script, used the old way (`./script-name.sh`).

# Warning
***

Please take time to read the [disclaimer](disclaimer.md) before running anything from this repository.

# Installation
***

**Python CLI (recommended for converted tools):**

```
pip install steamos-tools
steamos-tools --help
```

Or for local development, see [DEVELOPMENT.md](DEVELOPMENT.md) (uses [uv](https://astral.sh/uv)):

```
git clone https://github.com/mdeguzis/SteamOS-Tools
cd SteamOS-Tools/
./dev-setup.sh
uv run steamos-tools --help
```

Currently available via the CLI:

| Command | What it does |
|---|---|
| `steamos-tools proton get-ge <native\|flatpak\|steamos>` | Install the latest GE-Proton release |
| `steamos-tools screenshots link` / `sync` / `install` / `uninstall` | Sync Steam screenshots to a cloud remote via rclone |
| `steamos-tools rom migrate` / `strip-numbers` | Archive/unarchive ROMs against a match list, clean up scraper filename prefixes |
| `steamos-tools unlock` | Disable the SteamOS read-only filesystem and install base-devel |
| `steamos-tools shader check` / `trim` / `show-events` | Inspect and clean up Vulkan (Fossilize) shader caches |

**Remaining bash scripts:**

```
git clone https://github.com/mdeguzis/SteamOS-Tools
cd SteamOS-Tools/
./script-name.sh
```

# Updating
***

Python CLI: `pip install --upgrade steamos-tools`.

Bash scripts / repo clone:

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
* steamostools/ - The Python package: shared libraries and the `steamos-tools` CLI.
* tests/ - Unit and integration tests for `steamostools/`.
* utilities/ - Scripts not yet converted to the Python CLI, plus standalone tools.
* pyproject.toml, dev-setup.sh, DEVELOPMENT.md - Python packaging and local dev setup.
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
