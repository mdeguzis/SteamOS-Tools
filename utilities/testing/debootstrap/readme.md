# Some Notes
* IN-PROGRESS for chroots and docker work
* Files in this folder tree are not complete!
* For examples see Tianon's [gentoo repository](https://github.com/tianon/gentoo-overlay/tree/master/dev-util/debootstrap-valve/files/scripts)
* Once verfied, these scripts may be used to build a chroot/docker for SteamOS from a Debian system.

# Key points
* Valve's "debootstrap" package is bare (ie, the script inside is just a symlink: no default_mirror, no keyring, etc)
