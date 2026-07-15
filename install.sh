#!/usr/bin/env bash

set -euo pipefail

echo "==> System updation..."
sudo pacman -Syu --noconfirm

echo "==> Package installation..."
sudo pacman -S --noconfirm --needed wget curl btop mc fastfetch neovim 

echo "==> Package installation..."
sudo pacman -S --noconfirm --needed base-devel

echo "==> Package installation..."
sudo pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xsetroot

echo "==> Insatallation"
sudo pacman -S --noconfirm --needed libx11 libxft libxinerama

echo "==> Копирование dotfiles..."
mkdir -p "$HOME/suckless"

cd suckless

git clone git://git.suckless.org/dwm
cd dwm
sudo make clean install
cd ..

git clone git://git.suckless.org/st
cd st
sudo make clean install
cd..

git clone git://git.suckless.org/dmenu
cd dmenu
sudo make clean install


# Additional packages
sudo pacman -S --noconfirm --needed feh
