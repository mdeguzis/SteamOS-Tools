#!/bin/bash

CURDIR="${PWD}"
echo "[INFO] unlocking immutable OS"

sudo frzr-unlock
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Sy

# https://github.com/Jguer/yay
echo "[INFO] Installing 'yay' for user repository packages"
pacman -S --needed git base-devel
cd ~/src
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd "${CURDIR}}"

echo "[INFO] Installing supplemental software to OS"

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

