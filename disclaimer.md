## Disclaimer
Please take time to read the following!

### General overview

These scripts are written for, and developed on official Valve SteamOS installations. By using this repository, you accept all associated risk. If you are not comfortable using unofficial software and scripts, I do not suggest continuing.

### Backup your data!

Usage of these scripts is at your own risk! If you are at all concerned about the safety of your SteamOS installation, **please** have a recent or base root partition backup ready! This is typically captured when SteamOS is first installed. If you wish to update it, and feel ok doing so, please do so now. While this does not protect you from all things included, it will preserve and restore the vital parts of SteamOS.

### Capturing a backup

This can be found in the grub boot menu when you first start your PC. Pressing `Esc` right after POST or before the SteamOS boot menu will half the process and present the boot menu itself to you. If the boot process dissappears too quickly for your tastes,  change the `GRUB_HIDDEN_TIMEOUT_QUIET` to `true` and the `GRUB_TIMEOUT` settings to 3 or 4 seconds in `/etc/default/grub`. Please reference the example snippet below. You will then need to run `sudo update-grub` at a terminal window to update the grub boot file.

```
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=3
```

If any of this is foreign, or greek to you, it may be best to not proceed. However, a proper root backup should be fine if you do harm to your system. Please be advised that the root partition recovery will not touch the `/home` user partition. Any files contained within `/home` will be preserved. Besides the root partition, please take care to backup any files you are concerned about.

### Notes regarding apt-pinning / apt-preferences 

Apt-pinning is implemented in the `configure-repos.sh` script to ensure Steam and SteamOS release still take highest priority. LibreGeek / SteamOS-Tools packages follow suit in priority. Beneath this, Debian and Debian-Backports are given a lower priority. For details on current pin levels, please reference [these](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/master/configure-repos.sh#L111) lines of code. If the line number is off, the section is titled "# Create and add required text to preferences file". 

Apt-pin preferences are subject to change. Ideally, the testing branch will be tested properly before hand, and package policy checked with `apt-cache policy` as well. Please submit any suggestions or corrections anyone feels should be made as a pull request.

### Installing and Uninstalling software

Please pay careful attention while installing software lists, packages, or using any scripts that require software installation. I do my best to ensure no software list or singular package is going to remove or overwrite a Valve SteamOS/Steam package, but please be advised. If a software routine, or software install requires to remove* software, please read the output throughly before proceeding. 

Removing software packages can be tricky, so while there is a "uninstall" option to several scripts, please excercise caution, or remove packages one by one to ensure they will not remove critical SteamOS packages. A listing of default SteamOS packages can be found on [Distrowatch](http://distrowatch.com/table.php?distribution=steamos), as well as http://repo.steampowered.com.

### Conclusion

If you disregard any of these points, I will **not** be responsible for damage done to your SteamOS installation. Please heed these warnings! Mistakes happen with packages, upgrades, and the like. If you experience any issues, please submit an [issues](https://github.com/ProfessorKaos64/SteamOS-Tools/issues) ticket.
