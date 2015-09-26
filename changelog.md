SteamOS-Tools 2.5.7
  * Added Kodi 15 "Isengard" (packaged) to Libregeek brewmaster repository
  * Many wiki additions

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 26 September 2015 17:42:00 -5000

SteamOS-Tools 2.5.5
  * Added Kodi (packaged) to Libregeek brewmaster_testing
  * Fixed up build-kodi-src with Bluray and Airtunes support
  * Code cleanup
  * Code fixes
  * Added option to enabled testing Libregeek repo in add-debian-repos.sh

-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 22 September 2015 09:02:00 -5000

SteamOS-Tools 1.8.5
  * Fix GPG function not correctly verifying keys
   * Public key verification would skip if a restore was done via grub for SteamOS
   * The keys would be listed in the home users gpg keyring, but they were not truly in the system
   * Rather than use 'gpg --list-keys', use gpg --batch --quiet --edit-key KEYID check clean save quit to verify
  * Fix errors in Kodi-src build script
   * Added a bunch of packages to libregeek brewmaster repo to fix
   * run software list through desktop-software.sh to validate all packages (except optional packaging deps)
   * syntax error corrections
   * verified routine several times then from base-VM snapshot of brewmaster

-- ProfessorKaos64 <mdeguzis@gmail.com>  Tue, 22 September 2015 09:02:00 -5000

SteamOS-Tools 1.7.2
  * Restructure kodi-src script
   * Push software list through desktop-software.sh to validate packages
   * validate packages that needed installed through multiple VM test runs
  * correct GPG key checks in desktop-software.sh
  * Started to assess fixing up bad codding in scipts via shellecheck.net

-- ProfessorKaos64 <mdeguzis@gmail.com>  Mon, 21 September 2015 21:28:00 -5000

SteamOS-Tools 1.5.2
  * Fixed package version conflict for libcrossguid1, libcrossguid-dev in libregeek repository
  * augment version number (see above) for small changes

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 19 September 2015 13:09:00 -5000

SteamOS-Tools 1.5
  * Fixed utilities/build-scripts/build-kodi-from-src
  * Attempt to package this will follow soon

-- ProfessorKaos64 <mdeguzis@gmail.com>  Sat, 19 September 2015 11:06:00 -5000

SteamOS-Tools 1.2
  * Added new packages to brewmaster_testing
   * grive
   * google-chrome-stable
 * shaped up code [see commits]
 * Updated many wiki documents

-- ProfessorKaos64 <mdeguzis@gmail.com>  Fri, 18 September 2015 10:06:00 -5000
