#!/bin/bash

set -e -o pipefail

CURDIR="${PWD}"
echo "[INFO] unlocking immutable OS"

if which frzr-unlock &> /dev/null; then
	sudo frzr-unlock
	sudo pacman-key --init
	sudo pacman-key --populate archlinux
else
	sudo steamos-readonly disable
	sudo pacman-key --init
	sudo pacman-key --populate holo
fi
sudo pacman -Sy

# https://github.com/Jguer/yay
echo "[INFO] Installing 'yay' for user repository packages"
sudo pacman -S --noconfirm --needed git base-devel
cd ~/src
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd "${CURDIR}"

echo "[INFO] Installing supplemental software to OS"

# Flatpaks
flatpak install --user --noninteractive flathub io.github.philipk.boilr

# Transmission
sudo pacman -Sy transmission-cli libnatpmp libb64
sudo systemctl enable transmission.service
sudo mkdir /etc/systemd/system/transmission.service.d
sudo bash -c "echo -e \"[Service]\nUser=${USER}\" > /etc/systemd/system/transmission.service.d/username.conf"
sudo systemctl stop transmission.service
# Update config and start service
read -erp "Opening ~/.config/transmission-daemon/settings.json. Please update rpc username/password..."
vim "~/.config/transmission-daemon/settings.json"
sudo systemctl start transmission.service

# https://github.com/Tormak9970/Steam-Art-Manager
# TODO - make this dynamic for any app images...

