## Manifest
These are some known/unknown file dumps / pieces of SteamoS 3.0 / Steam Deck's gamepadUI inner workings. WIP collection of possible helpful elements

## Primary elements

* Repository/Arch Mirror: https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/

## Table

| package | link | description | notable files | 
| ------- | ---- | ----------- | ------------- |
|steam-jupiter-stable-1.0.0.74-2.13-x86_64.pkg.tar.zst | [link](https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/steam-jupiter-stable-1.0.0.74-2.13-x86_64.pkg.tar.zst) | unknown | |
|steamos-customizations-jupiter-20220227.2-1-any.pkg.tar.zst| [link](https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter/os/x86_64/steamos-customizations-jupiter-20220227.2-1-any.pkg.tar.zst) | unknown | |

## Package Deep Dives / Inspection

### steamos-customizations-jupiter

* /usr/lib/systemd/system/system-generator/steamos-steamlib-generator: Seems to be the magic for the multiple libraries

