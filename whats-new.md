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
   * Rather than use 'gpg --list-keys', use gpg --batch --quiet --edit-key KEYID check clean save quit to verify
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
