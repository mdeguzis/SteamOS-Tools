# SteamOS-Tools Update Log #44

  * Pushed new build of `citra` to brewmaster_testing
  * Pushed new build of `openpht` 1.5.2 to brewmaster_testing
  * Updated a metric ton of libretro-core build scripts with new build script code.
  * Subsequently, many libretro cores have been updated against the latest upsteam code
  * Modified [configure-packaging-env.sh](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging/tree/brewmaster/setup-files) to allow building a pbuilder environment on other Debian systems, as well as Arch Linux!
   * To achive this, devscripts had to "forked" from the AUR to fix it for the latest devscripts Debian package.
   * The other packages are sourced from the Arch Linux main repositories, as well as the AUR.
   * If SteamOS is detected during pbuilder chroot creation, $HOME is target for apt package cache, over root, due to 10 GB standard restrictions. This causes issues with large build projects.
   * pbuilder chroots already are stored in $HOME/pbuilder.

-- ProfessorKaos64  <mdeguzis@gmail.com>  Fri, 04 Mar 2016 17:34:00 -0500

# SteamOS-Tools Update Log #43

  * `pcsx2-unstable` updated to laetst upsteam commit
  * `citra` the popular, yet experimental/early 3DS emulator now has an early package build
  * This build uses an early un-merged PR from upstream that replaces GWFL with SDL2
  * For now, this will stay in brewmaster_testing
  * Constructed a virtual package for UT-Alpha, however, it is unknown if this will replace the 'desktop-software.sh' build script wrapper hook.
  * SteamOS-Tools packages auto-update alongside Valve's, so required a lot of extra time for a large package may not be ideal.

-- ProfessorKaos64  <mdeguzis@gmail.com>  Wed, 03 Mar 2016 19:20:00 -0500

# SteamOS-Tools Update Log #42

 * The Dark Mod is now copied over to the regular brewmaster repository
 * `darkmod` is essentially a virtual package with a few tricks to it
 * modifications done were a bit hacky, so it there is anyone that knows better, a PR is more than welcome at [SteamOS-Tools Packaging](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging)
 * Many tests were done to ensure the 32-bit dependencies were met to run The Dark Mod and provide a 1 step install
 * This is accomplished via the "virtual package" + a few hacky tricks to prepare things for SteamOS / Debian 8
 * `/usr/games/darkmod` is a symbolic link to either
  * `/usr/share/games/darkmod/thedarkmod.x86`
  * `/home/steam/darkmod/thedarkmod.x86`
  * This is due to the base install of / on SteamOS being 10 GB, where /usr sits.
  * Other Debian distro's (which this should also run on), should not have such a small / partition
 * Desktop file
 * Artwork
 * After the `darkmod` is installed, the "online updater" will fire off and grab the game files. If a game file exists, it will be checked against the server version (standard behavior)
 * There are still efforts to compile the entire project (which I have figured out most of). However, this approach seemed to work fairly well on Debian 8 and SteamOS. If you do inspect debian/control, you'll notice a large batch of 32-bit libraries. The Dark Mod is a 32 bit application still (I believe there are future plans to move to 64 bit on the forums), so these are required.

-- ProfessorKaos64  <mdeguzis@gmail.com>  Fri, 26 Feb 2016 20:09:00 -050

# SteamOS-Tools Update Log #42

  * `voglperf` package added to brewmaster_testing (needs some kinks worked out yet, but runs)
  * See: https://github.com/ProfessorKaos64/voglperf/
  * `lutris` version 3.7.2 uploaded to brewmaster repository
   * See the wiki entry linked below for notes about running in BPM
   * Suggestion: (untested personally yet), use the Kodi addon noted [here](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Lutris)
   * It is unknown yet if a simple pacakge will be made for the Kodi addon, or to facilitate adding SuperRepo sources

-- ProfessorKaos64  <mdeguzis@gmail.com>  Tue, 23 Feb 2016 19:52:00 -0500

# SteamOS-Tools Update Log #41

  * `ppsspp` (git) now added (over previous PPA-sourced package), version 1.2.1
  * This includes a ton of improvments, and early support for future API's (such as Vulkan)
  * See: http://ppsspp.org/#news
  * Thank you to the folks over at github.com/hrydgard/ppsspp for the help with the rules file/packaging

-- ProfessorKaos64  <mdeguzis@gmail.com>  Mon, 22 Feb 2016 17:41:00 -0500

# SteamOS-Tools Update Log #40

  * Kodi 16 Jarvis, released yesterday, built and synced to the main repository.
  * Along with this, all build depedencies and PVR addons have updated/built as well.
  * ice-steamos-unstable has been updated
  * Fixed steamos-tools-repo and steamos-tools-beta-repo package unattended configuration file
  * Note: If you are presented with any prompts to overwrite configuration files, choose to install the maintainer's version.
  * Please submit any issues as a bug report.
  * Fixed some issues in pbuilder setup for packaging

-- ProfessorKaos64  <mdeguzis@gmail.com>  Sun, 21 Feb 2016 07:44:00 -0500

# SteamOS-Tools Update Log #39

  * Updated all [build scripts](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging) to utilize `pbuilder`/`pdebuild` by default (Set BUILDER="") inside script
  * See script header option `BUILDOPTS="options"` for passing arguments to `${BUILDER}`, such as `--debbuildopts -b`
  * Packaging [setup files](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging/tree/brewmaster/setup-files) expanded upon
   * `configure-packaging-env.sh` configures some base options for building, and configures pbuilder
   * `setup-pbuilder.sh` (called by the above script) configures pbuilder, installs necessary keyrings, and copys `pbuilder-wrapper.sh` wrapper script into a system path for easy execution anywhere
   * Much yet to improve, but tested several builds today (including Kodi 16.0rc3-Jarvis!)
  * The old `add-debian-repos.sh` was retired, with `configure-repos.sh` taking it's place
   * Uses a "Debianized" GPG keyring package, along with packaged versions of the `steamos-tools-repo`, and `steamos-tools-beta-repo` repository.
  * Pushed Kodi 16.3rc3-Jarvis to brewmaster_testing to begin eval for upcoming release (syncing now)
  * The "source" for Streets of Rage Remake I had used, seems to no longer be around. The source code is not really improved anymore, but it should be known that no real updates (besides any packaging fixes) will be done.
  * Please also see the README.md file in the repository root for updated notes on most of the above.

-- ProfessorKaos64  <mdeguzis@gmail.com>  Tue, 16 Feb 2016 19:31:00 -0500

# SteamOS-Tools Update Log #39

  * Converted "add-debian-repos.sh" to proper Debian packages
  * See [libregeek-archive-keying](http://packages.libregeek.org/SteamOS-Tools/pool/main/libr/libregeek-archive-keyring/)
  * See [steamos-tools-repo](http://packages.libregeek.org/SteamOS-Tools/pool/main/libr/libregeek-repo/) and [steamos-tools-beta-repo](http://packages.libregeek.org/SteamOS-Tools/pool/main/libr/libregeek-repo/)
  * The old `add-debian-repos.sh` script has been retired into the "old" folder at the repository root

-- ProfessorKaos64  <mdeguzis@gmail.com>  Sun, 14 Feb 2016 10:22:00 -0500

# SteamOS-Tools Update Log #38

  * Added experimental [koku-xinput-wine](https://github.com/ProfessorKaos64/koku-xinput-wine) package to brewmaster_testing (32-bit only, needs a lot of testing).
  * Please see the README.md file for me (LD_PRELOAD library)
  * Added `playonlinux-unstable` to the main repository after some brief functional tests.
  * playonlinux-unstable follows the latest [POL4 code base](https://github.com/PlayOnLinux/POL-POM-4)
  * Added ~ 20160123, was the much needed shortcut for the Wine Control Panel (see: applications > configuration)
  * Previously this was launchable only from the cmd prompt of a Wine "drive/bottle."
  * See: packages.libregeek.org

-- ProfessorKaos64  <mdeguzis@gmail.com>  Fri, 12 Feb 2016 23:30:00 -0500

# SteamOS-Tools Update Log #37

  * Added simple Minecraft package, package name `minecraft`
  * Please read the notice displayed in the terminal window after installation
  * You must register ahead of time, as the browser window it tries to open to register will not show on SteamOS
  * See: packages.libregeek.org
  * Reminder, `minetest`, an open source infinite-world block sandbox game with survival and crafting is also available in the Debian repositories. 
  * Improved POL launch script template (see cfgs/wine/pol-game-launcher.skel)
   * Monitors PID of GAME_EXE over name (which was getting cut off for long names)
   * Sends basic log information to `/tmp/wine-game-log.txt' (rolls over at max 20M size)
   * [Sample log output](http://slexy.org/raw/s20UDBH1PJ)

-- ProfessorKaos64  <mdeguzis@gmail.com>  Wed, 10 Feb 2016 21:37:00 -0500

# SteamOS-Tools Update Log #36

  * ice-steamos-unstable was updated to the latest upstream master tree commit
  * Update 145+ [build scripts](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging) with the following:
   * debuild now in use over dpkg-buildpackage
   * The "--testing" option flag to push packages intended for "DIST_testing" to the proper location after the build
  * Eventually, the intention is to have a reliable pbuilder setup (still new to using it) to keep my test machine "sane."
  * Work on "configure-packaging-env.sh" to setup build tools and install packages
  * All of the above is in preperation to build Kodi 16 "Jarvis" into brewamster_testing (Currently release RC3)
  * Remember, you must pass "--enable-testing" to "add-debian-repos.sh" to work with these packages (at your own risk!)
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging

-- ProfessorKaos64  <mdeguzis@gmail.com>  Wed, 10 Feb 2016 20:15:00 -0500

# SteamOS-Tools Update Log #35

  * ice-steamos-unstable was updated to the latest upstream master tree commit
  * pcsx2 has now been split into **pcsx2**, and **pcsx2-unstable**. 
  * pcsx2 will follow the latest release tag upstream (which is only feasible for projects that maintain them regulary)
  * pcsx2-unstable will be a semi-daily snapshot of the master source tree's latest commit at time of build
  * Due to restrictions with reprepro at the moment (until I find a better way), _please [purge and reinstall](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Purging-and-Reinstalling-a-Package) pcsx2_
  * I apologize for any inconvenience this has caused
  * obs-studio has been updated to the latest upstream release, 0.13.1
  * Fixed RetroArch v1.3.1 not autoconfiguring gamepads. This is done by default now
  * See SteamOS-Tools-Packaging, commit [edbedec](https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging/commit/edbedec636b158869b8bc317f15103b28bd0e6ff)
  * Update retroarch-joypad-autoconfig for the latest changes/profiles

-- ProfessorKaos64  <mdeguzis@gmail.com>  Mon, 8 Feb 2016 22:34:00 -0500

# SteamOS-Tools Update Log #34

  * Added working build of Sonic Robo Blast 2 (fan made Sonic 3D game, using Doom open source engine)
  * [Details / Annoucment for SRB2](http://steamcommunity.com/groups/steamuniverse/discussions/0/412446292766218435)
  * Fork: https://github.com/ProfessorKaos64/SRB2
  * Upstream: https://github.com/STJr/SRB2
  * Add _binary only_ package of Sonic The Hedgehog 3D, `sonic3d` (fan made). No source code is available
  * See: http://www.indiedb.com/games/sonic-the-hedgehog-3d
  * Sonic 3D needs controls tweaked, or better yet, use a Steam Controler (as the game has full camera control)
  * Streets of Rage Steam Controller profile is now live (lame 1 hour wait)

-- ProfessorKaos64  <mdeguzis@gmail.com>  Sun, 7 Feb 2016 17:42:00 -0500

# SteamOS-Tools Update Log #33

  * Added working build of OpenLieroX `openlierox` to package pool (A clone of Liero, Worms-style game)
  * New build of ice-steamos-unstable per upstream latest commit
  * _All_ Kodi PVR addons have been rebased/rebuilt against Isengard to ensure they are "level", should fix issues/123
  * Due to package versioning conflicts (date vs actual version), and that reprepro only can contain one version, please run `sudo apt-get purge kodi-pvr-ADDON && sudo apt-get install kodi-pvr-ADDON`
  * Replace "ADDON" with the PVR you wish to install
  * I apologize for any convenience this caused
  * On a lighter note, Kodi 16 Jarvis RC3 released yesterday. Shouldn't be much longer :)

-- ProfessorKaos64  <mdeguzis@gmail.com>  Fri, 5 Feb 2016 20:30:00 -0500

# SteamOS-Tools Update Log #32

  * New build of ice-steamos-unstable per upstream latest commit
  * New release of pcsx2
  * [openpht 1.5.1](https://github.com/RasPlex/OpenPHT/releases/tag/v1.5.1.508-67218541) is released! 
  * Due to package versioning conflicts (date vs actual version), and that reprepro only can contain one version, please run `sudo apt-get purge openpht && sudo apt-get install openpht`
  * I apologize for any convenience this caused

-- ProfessorKaos64  <mdeguzis@gmail.com>  Tue, 2 Feb 2016 21:12:00 -0500

# SteamOS-Tools Update Log #31

  * ice-steamos / ice-steamos-unstable upgraded to ensure each repository would remove/replace the other
  * New build of ice-steamos-unstable per upstream latest commit
  * Typhoon 2001 (A Tempest 2000 clone) ressurrected, packaged, and added to package pool
  * Feedback for Typhoon 2001 is welcome, but as a static binary, there isn't much I can fix
  * [Release announcement for Typhoon 2001](https://www.reddit.com/r/SteamOS/comments/43rolg/typhoon_2001_a_tempest_2000_clone_resurrected_and/)
  * See: https://github.com/ProfessorKaos64/typhoon2001

-- ProfessorKaos64  <mdeguzis@gmail.com>  Mon, 1 Feb 2016 20:00:00 -0500

# SteamOS-Tools Update Log #30

  * ice-steamos_1.0.0+bsos3 synced to repository
  * Added man page for ice-steamos, run "man ice-steamos" to view information
  * This release of ice-steamos supports the available command line options

-- ProfessorKaos64  <mdeguzis@gmail.com>  Sat, 30 Jan 2016 16:34:32 -0500

# SteamOS-Tools Update Log #29

  * Updated packages:
   * ice-steamos (new 1.0.0 upstream release)
   * ice-steamos-unstable
  * The rest of available updates for pacakge will follow into this weekend.
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Packaging-Information

-- ProfessorKaos64 <mdeguzis@gmail.com>  Fri, 29 Jan 2016 22:56:00 -0500

# SteamOS-Tools Update Log #28

  * Updated packages:
   * antimicro
   * emulationstation
   * emulationstation-theme-simple
   * itch (opens now via BPM, but games do not launch)
   * lutris
   * obs-studio
   * ppsspp
   * pcsx2
  * The rest of available updates for pacakge will follow into this weekend.
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Packaging-Information

-- ProfessorKaos64 <mdeguzis@gmail.com>  Thu, 28 Jan 2016 21:25:00 -0500

# SteamOS-Tools Update Log #27

  * ice-unstable updated to latest upstream changes
  * Conversion will be taking place to update all build scripts with fixed .orig archives to follow pkg ver/rev

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 25 Jan 2016 21:00:00 -0500

# SteamOS-Tools Update Log #26

  * As of the latest Steam Client beta for 20160126, Xephyr hack for Chrome no longer needed.
  * Old Default-Launch.sh file appended with .old for preservation.
  * This also means that the Google Chrome application will functions fine when used by itself.
  * SNIS (Space Nerds in Space) package updated with latest upstream commits.

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 25 Jan 2016 21:00:00 -0500

# SteamOS-Tools Update Log #25

  * Added Mari0 build/package (Mario+Portal)
  * Added SORR (Streets of Rage Remake) build/package
  * Steam Controller profiles for each game are already made
  * Profiles will be uploaded as soon as the 1 hour minimum test time elapses on Steam
  * Updated ice-unstable
  * See: http://packages.libregeek.org/SteamOS-Tools/package_lists/

-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 23 Jan 2016 21:25:00 -0500

# SteamOS-Tools Update Log #23

  * "ice-steamos" package added to Libregeek pacakge pool
  * See: https://github.com/ProfessorKaos64/Ice
  * Many thanks to Sharkwouter for all his hard work, as well as Ryochan7
  * Kodi "Jarvis" seems to soon on the horizon, so stay tuned
  * PlayOnLinux launcher configs are being updated, bear with me as they are tested

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sun, 17 Jan 2016 21:00:00 -0500

# SteamOS-Tools Update Log #22

  * ATTN: Due to a package mismatch in the repository it is _highly_ suggested you read the below information.
  * If you are having upgrade issues where you upgrade SteamOS, yet the icon still remains, please see the [debugging SteamOS upgrades](https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Troubleshooting#debugging-steamos-upgrade-issues) wiki page
  * If you see any output from a debug run of unattended-upgrade or a dry-run that indicates connfile prompts, remove and reinstalling the package in question should solve it.
  * The unattended configuration is being looked at for improvements to avoid connfiles prompts or handle them appropriately.

-- ProfessorKaos64 <mdeguzis@gmail.com>  Thu, 07 Jan 2016 21:41:00 -0500

# SteamOS-Tools Update Log #21

  * Added unattended steamos tools pkg updates
  * You _must_ run ./add-debian-repos.sh again from teh GitHub repository root
  * Please do submit an issues ticket if you have problems upgrading Valve or SteamOS-Tools packages
  * https://github.com/ProfessorKaos64/SteamOS-Tools/issues
  * https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Troubleshooting

-- ProfessorKaos64 <mdeguzis@gmail.com>  Thu, 07 Jan 2016 06:41:00 -0500  

# SteamOS-Tools Update Log #20

  * Added awstats pulic usage statistics page for tracking popular packages and other items
  * Results will be available starting in 24 hours from now on (will start from 0)
  * See: http://steamos-tools-stats.libregeek.org
  * See: http://stats.libregeek.org for global site statistics
  * Feedback is very welcome
  * All of the statistical reports are updated every 24 hours.

-- ProfessorKaos64 <mdeguzis@gmail.com>  Wed, 06 Jan 2016 06:43:00 -0500  

# SteamOS-Tools Update Log #19

  * Added gngeo package to package pool
  * Started higan build
  * After some reprepro mess, package pool is back fully up and running
  * All retroarch/libretro package build scripts update and built over last 2 days
  * Added some new wiki pages for how-to, as well as runnings Steam for Windows games on SteamOS
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Tutorials-and-How-To
 
-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 05 Jan 2016 22:06:00 -0500  

# SteamOS-Tools Update Log #18

  * Added script function to desktop-software for itch.io client (needs tested)
  * Added full wiki page for Steam under Wine (POL) and how to add games
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Playing-Steam-for-Windows-Games-On-SteamOS
  * Cleaned up a few files/folders
  * More active work being done to get a native build script of the Itch.io client
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/itch.io
 
-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 02 Jan 2016 22:00:00 -0500  

# SteamOS-Tools Update Log #17

  * Started Windows-Steam via Wine/POL implementation in testing-b branch
  * Updated Lutris to lutris_0.3.7.1 (inlcludes JSON support for Kodi addon)
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Lutris
 
-- ProfessorKaos64 <mdeguzis@gmail.com>  Wed, 30 Dec 2015 16:20:00 -0500  

# SteamOS-Tools Update Log #16

  * Started new brach of RetroRig-ES for use with SteamOS-Tools
  * I must stress this is WIP, just a fun experiement
  * See: https://github.com/ProfessorKaos64/RetroRig-ES/blob/brewmaster

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 28 Dec 2015 18:03:00 -0500

# SteamOS-Tools Update Log #16

  * Completed build scripts (source included) for all Retroarch / Libretro cores (a lot!)
  * Please report any issues with all source-built Retroarch/Libretro packages to the issues tracker
  * Finished modifying the vast majority of build scripts to inlucde full source in repository
  * Updated Kodi builds to prepare for upcoming Jarvis release
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging
  * Upcoming: Lutris updates, along with Lutris Kodi addon (thanks RobLoach!)

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sun, 27 Dec 2015 21:03:00 -0500

# SteamOS-Tools Update Log #15

  * Added fork of pastebinit (uses slexy as default PB)
  * Began laborious restructure of package build scripts to adjust for full-soruce uploads using .changes file
  * Completing this restrucutre will take some time over the next week or two (retroarch/kodi the largest).
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging/

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sun, 20 Dec 2015 19:37:00 -0500

# SteamOS-Tools Update Log #14

  * Please see commit logs for full detail
  * Add xwiimote/libxwiimote/libxwiimote2 packages to brewmaster pool
  * See the wiki for full packaging details
  * Upsteam: https://github.com/dvdhrm/xwiimote
  * Fork (with packagin): https://github.com/BrainTech/xwiimote

-- ProfessorKaos64 <mdeguzis@gmail.com>  Fri, 18 Dec 2015 21:37:00 -0500

# SteamOS-Tools Update Log #13

  * Please see commit logs for full detail
  * Change this file to a "what's new" format, blog style
  * Added abiliyt to 'add-debian-repos' to add just Debian sources, if desired
  * Started work on network share add/attach script
  * Updated SNIS from SteamOS-Tools fork, follow new "release" schedule

-- ProfessorKaos64 <mdeguzis@gmail.com>  Thu, 17 Dec 2015 08:00:00 -0500

# SteamOS-Tools Update Log #12

  * Packaged OpenPHT (early testing) in brewmaster_testing
  * Completed basic set of Debian traditional packaging for Kodi packages (including PVR)
  * Completed basic set of Debian traditional packaging for Retroarch (early testing) 
  * Completed basic set of Debian traditional packaging for Libretro cores (early testing) 
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging
  * Fixed web apps
  * Fixed debian repo additions to use http redirect servers (global)
  * Begin work on GOG download tool (thanks to Sharkwouter)
  * Updated packages (see full software hosting list on wikI)
  * Investigated several ventures for fixes

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 07 Dec 2015 16:32:00 -0500

# SteamOS-Tools Update Log #11

  * Packaged python-evdev for packages.libregeek.org
  * Packaged ds4drv for packages.libregeek.org
  * Updated OBS-Studio with proper debian packaging, release 0.12.2
  * Wiki updated for pairing DS4/PS4 controllers
  * Began work on creating post-configure package for Retroarch
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools-Packaging

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sun, 22 Oct 2015 16:32:00 -0500

# SteamOS-Tools Update Log #10

  * Updated Kodi to Isengard 15.2 latest git stable release
  * Built all available Kodi PVR addons to libregeek repository
  * Moved build scripts (increasing in number) to SteamOS-Tools-Packaging repo
  * See: https://github.com/ProfessorKaos64/SteamOS-Tools/wiki/Kodi for notes

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sun, 15 Oct 2015 22:08:00 -0500

# SteamOS-Tools Update Log #9

  * Updated Kodi to Isengard 15.2 stable release
  * Updated Retroarch from latest PPA stable release
  * Updated Libretro cores from latest PPA stable releases
  * Updated obs-studio from latest git upstream source version
  * Updated qtsixa from latest git upstream source version
  * Updated Dolphin emulator from latest PPA stable source
  * Added dolphin-emu-master, stable variant of Dolphin Emulator

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 31 Oct 2015 14:58:00 -0500

# SteamOS-Tools Update Log #8

  * Sytax corrections
  * Added obs-studio, ffmpeg, pcsx2, stepmania, dolphin-emu to brewmaster dist release
  * Added speedtest-cli, simplescreenrecorder, skype, spotify-client  to brewmaster dist release
  * Added obs-studio (git), ffmpeg (git), pcsx2-unstable (git) to brewmaster_testing dist release
  * Please check the wiki for supplemental information

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 05 Oct 2015 07:00:00 -0500

# SteamOS-Tools Update Log #7

  * Sytax corrections
  * Several new packages added to repository (check the wiki)

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 03 Oct 2015 19:49:00 -0500

# SteamOS-Tools Update Log #6

  * Added Kodi 15 "Isengard" (packaged) to Libregeek brewmaster repository
  * Many wiki additions

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 26 Sep 2015 17:42:00 -0500

# SteamOS-Tools Update Log #5

  * Added Kodi (packaged) to Libregeek brewmaster_testing
  * Fixed up build-kodi-src with Bluray and Airtunes support
  * Code cleanup
  * Code fixes
  * Added option to enabled testing Libregeek repo in add-debian-repos.sh

-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 22 Sep 2015 09:02:00 -0500

# SteamOS-Tools Update Log #5

  * Fix GPG function not correctly verifying keys
   * Public key verification would skip if a restore was done via grub for SteamOS
   * The keys would be listed in the home users gpg keyring, but they were not truly in the system
   * Rather than use 'gpg--list-keys', use gpg--batch--quiet--edit-key KEYID check clean save quit to verify
  * Fix errors in Kodi-src build script
   * Added a bunch of packages to libregeek brewmaster repo to fix
   * run software list through desktop-software.sh to validate all packages (except optional packaging deps)
   * syntax error corrections
   * verified routine several times then from base-VM snapshot of brewmaster

-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 22 Sep 2015 09:02:00 -0500

# SteamOS-Tools Update Log #4

  * Restructure kodi-src script
   * Push software list through desktop-software.sh to validate packages
   * validate packages that needed installed through multiple VM test runs
  * correct GPG key checks in desktop-software.sh
  * Started to assess fixing up bad codding in scipts via shellecheck.net

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 21 Sep 2015 21:28:00 -0500

# SteamOS-Tools Update Log #3

  * Fixed package version conflict for libcrossguid1, libcrossguid-dev in libregeek repository
  * augment version number (see above) for small changes

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 19 Sep 2015 13:09:00 -0500

# SteamOS-Tools Update Log #2

  * Fixed utilities/build-scripts/build-kodi-from-src
  * Attempt to package this will follow soon

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 19 Sep 2015 11:06:00 -0500

# SteamOS-Tools Update Log #1

  * Added new packages to brewmaster_testing
   * grive
   * google-chrome-stable
 * shaped up code [see commits]
 * Updated many wiki documents

-- ProfessorKaos64 <mdeguzis@gmail.com>  Fri, 18 Sep 2015 10:06:00 -0500
