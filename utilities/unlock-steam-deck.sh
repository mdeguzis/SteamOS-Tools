#!/bin/bash
# Description: A small utility to unlock the read-only filesystem on the Steam Deck 
#              and install basic gpg keyrings/dev tools for installing software

echo "[INFO] Unlocking filesystem"
sudo steamos-readonly disable

echo "[INFO] Adding/updating Arch Linux keyrings"
sudo pacman-key --init
sudo pacman-key --populate archlinux

echo "[INFO] Updating repository index"
sudo pacman -Syy

echo "[INFO] Installing basic devtools"
sudo pacman -S --noconfirm base-devel