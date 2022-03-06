<!---toc start-->

  * [Warning](#warning)
  * [Script Helper](#script-helper)
  * [Manifest](#manifest)
  * [Primary elements](#primary-elements)
  * [Table](#table)
  * [Package Deep Dives / Inspection](#package-deep-dives--inspection)
    * [steamos-customizations-jupiter](#steamos-customizations-jupiter)
  * [Troubleshooting](#troubleshooting)
    * [Reset](#reset)

<!---toc end-->

## Warning
All things below are to be done AT YOUR OWN RISK! I am not responsible for any fallout from tinkering with this new UI on non-Steam Deck devices

## Script Helper
See `steam-deck.sh` in this directory for simple method to toggle the new gamepadUI on/off.

## Manifest
These are some known/unknown file dumps / pieces of SteamoS 3.0 / Steam Deck's gamepadUI inner workings. WIP collection of possible helpful elements

## Primary elements

* Repository/Arch Mirror: https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/

## Table

| package | link | description | notable files | 
| ------- | ---- | ----------- | ------------- |
|steam-jupiter-stable | [link](https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/steam-jupiter-stable-1.0.0.74-2.13-x86_64.pkg.tar.zst) | unknown | |
|steamos-customizations-jupiter| [link](https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/steamos-customizations-jupiter-20220227.2-1-any.pkg.tar.zst) | unknown | |
| jupiter-hw-support | [link](https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/jupiter-hw-support-20220224.1.2-1-any.pkg.tar.zst) | unknown |

## Package Deep Dives / Inspection

### steamos-customizations-jupiter

* /usr/lib/systemd/system/system-generator/steamos-steamlib-generator: Seems to be the magic for the multiple libraries


## Troubleshooting

### Reset
Running into trouble after messing too much with things? You can try a few things (at your own risk)

1. Remove `/.local/share/Steam/config/Config.vdf` (will force you to re-enter login details). 
2. Run `steam-runtime --reset` (reset pretty much everything for Steam)
