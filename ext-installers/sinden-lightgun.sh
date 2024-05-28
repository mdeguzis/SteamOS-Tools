#!/bin/bash
# See: https://sindenlightgun.com/drivers/

drivers_loc="${HOME}/software/drivers"
ver="2.05c"
release="Beta"

mkdir -p "${drivers_loc}"
cd "${drivers_loc}"
curl -LO https://www.sindenlightgun.com/software/Linux${Beta}${version}.zip
unzip Linux${release}${version}.zip
cp -r Linux${release}${verison}/PCversion/Lightgun "${HOME}"
rm -rf Linux${release}${version}

# Configuration
sudo pacman -Sy --noconfirm  mono sdl12-compat sdl_image sdl
sudo usermod -a -G uucp "${USER}"

echo "[INFO] Press ENTER to proceed to configuration screen"
read
cd "${HOME}/Lightgun"
sudo mono LightgunMono.exe steam joystick sdl

