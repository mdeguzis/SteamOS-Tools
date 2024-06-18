#!/bin/bash

set -e -o pipefail

CURDIR="${PWD}"
echo -e "\n[INFO] unlocking immutable OS"

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

echo -e "\n[INFO] Installing Arch Linux packages"
# Arch packages that do not have Flatpaks
sudo pacman -S --noconfirm --needed \
	libnatpmp \
	libb64 \
	nodejs \
	npm \
	transmission-cli
 
# https://github.com/Jguer/yay
# SteamOS may lag a little behind with required deps (e.g. pacman), so manually
# update the tag as needed.
# Use yay-bin for the least amount of headaches...
if [[ ! -f "/usr/bin/yay" ]]; then
	echo -e "\n[INFO] Installing 'yay' for user repository packages"
	sudo pacman -S --noconfirm --needed git base-devel
	git clone https://aur.archlinux.org/yay-bin.git "${HOME}/src/yay-bin"
	git -C "${HOME}/src/yay-bin" checkout "96f90180a3cf72673b1769c23e2c74edb0293a9f"
	cd "${HOME}/src/yay-bin"
	makepkg -si
	cd "${CURDIR}"
fi

#echo -e "\n[INFO] Installing AUR Linux packages"

# Flatpaks
echo -e "\n[INFO] Installing Flatpaks"
flatpak install --user --noninteractive flathub io.github.philipk.boilr
flatpak install --user --noninteractive flathub com.github.tchx84.Flatseal
flatpak install --user --noninteractive flathub com.google.Chrome
flatpak install --user --noninteractive flathub com.heroicgameslauncher.hgl
flatpak install --user --noninteractive flathub com.transmissionbt.Transmission
flatpak install --user --noninteractive flathub io.itch.itch
flatpak install --user --noninteractive flathub net.lutris.Lutris
flatpak install --user --noninteractive flathub org.winehq.Wine
flatpak install --user --noninteractive flathub tv.plex.PlexDesktop
flatpak install --user --noninteractive flathub org.zdoom.GZDoom

# For Decky Loader dev
if [[ ! -f "${HOME}/.local/share/pnpm/pnpm" ]]; then
	echo -e "\n[INFO] Installing 'pnpm' for Decky Loader dev"
	sleep 2
	curl -fsSL https://get.pnpm.io/install.sh | sh -
fi

# Manage App Images
echo -e "\n[INFO] Installing 'Zap' to manager AppImages"
sleep 2
curl https://raw.githubusercontent.com/srevinsaju/zap/main/install.sh | bash -s

echo -e "\n[INFO] Installing AppImages via Zap"
sleep 2
zap install --no-interactive --github --from Tormak9970/Steam-Art-Manager

# Transmission
read -erp "Configure Transmission? (y/N)" CONFIG_TRANSMISSION
if [[ "${CONFIG_TRANSMISSION}" == "y" ]]; then
	sudo systemctl enable transmission.service
	sudo mkdir -p /etc/systemd/system/transmission.service.d
	sudo bash -c "echo -e \"[Service]\nUser=${USER}\" > /etc/systemd/system/transmission.service.d/username.conf"
	sudo systemctl stop transmission.service
	# Update config and start service
	read -erp "Opening ~/.config/transmission-daemon/settings.json. Please update rpc username/password..."
	vim "~/.config/transmission-daemon/settings.json"
	sudo systemctl start transmission.service
fi
