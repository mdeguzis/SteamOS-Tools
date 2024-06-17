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
# SteamOS may lag a little behind with required deps (e.g. pacman), so manually
# update the tag as needed.
# Use yay-bin for the least amount of headaches...
echo "[INFO] Installing 'yay' for user repository packages"
sudo pacman -S --noconfirm --needed git base-devel
if [[ ! -f "/usr/bin/yay" ]]; then
	git clone https://aur.archlinux.org/yay-bin.git "${HOME}/src/yay-bin"
	git -C "${HOME}/src/yay-bin" checkout "96f90180a3cf72673b1769c23e2c74edb0293a9f"
	cd "${HOME}/src/yay-bin"
	makepkg -si
	cd "${CURDIR}"
fi

echo "[INFO] Installing supplemental software to OS"

# Arch packages that do not have Flatpaks
sudo pacman -S --noconfirm --needed \
	libnatpmp \
	libb64 \
	nodejs \
	npm \
	transmission-cli

# Flatpaks
flatpak install --user --noninteractive flathub io.github.philipk.boilr

# For Decky Loader dev
echo -e "\n[INFO] Installing 'pnpm' for Decky Loader dev"
sleep 2
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Manage App Images
echo -e "\n[INFO] Installing 'zap' to manager AppImages"
sleep 2
curl https://raw.githubusercontent.com/srevinsaju/zap/main/install.sh | bash -s

echo -e "\n[INFO] Installing AppImages via Zap"
sleep 2
zap install --github --from Tormak9970/Steam-Art-Manager


# Transmission
sudo systemctl enable transmission.service
sudo mkdir -p /etc/systemd/system/transmission.service.d
sudo bash -c "echo -e \"[Service]\nUser=${USER}\" > /etc/systemd/system/transmission.service.d/username.conf"
sudo systemctl stop transmission.service
# Update config and start service
read -erp "Opening ~/.config/transmission-daemon/settings.json. Please update rpc username/password..."
vim "~/.config/transmission-daemon/settings.json"
sudo systemctl start transmission.service

