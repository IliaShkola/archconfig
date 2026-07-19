#!/usr/bin/env bash

set -euo pipefail

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  RESET=''
fi

log_info() {
  printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$1"
}

log_step() {
  printf '\n%b==> %s%b\n' "$CYAN" "$1" "$RESET"
}

log_success() {
  printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$1"
}

log_warn() {
  printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

if [[ $EUID -eq 0 ]]; then
  log_warn "Please run this script as a regular user."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pacman >/dev/null 2>&1; then
  log_warn "This script is intended for Arch-based systems with pacman."
  exit 1
fi

install_packages() {
  log_info "Installing packages with pacman..."
  sudo pacman -Syu --noconfirm
  sudo pacman -S --noconfirm --needed "$@"
}

build_and_install() {
  local repo_name="$1"
  local target_dir="$HOME/suckless/$repo_name"
  local config_source=""

  case "$repo_name" in
    dwm)
      config_source="$SCRIPT_DIR/configs/dwm/config.h"
      ;;
    st)
      config_source="$SCRIPT_DIR/configs/st/config.h"
      ;;
    dmenu)
      config_source="$SCRIPT_DIR/configs/dmenu/config.h"
      ;;
    slstatus)
      config_source="$SCRIPT_DIR/configs/slstatus/config.h"
      ;;
  esac

  log_step "Building and installing $repo_name"

  if [[ ! -d "$target_dir" ]]; then
    git clone --depth 1 "https://git.suckless.org/$repo_name" "$target_dir"
  else
    log_info "Updating $repo_name"
    git -C "$target_dir" pull --ff-only || true
  fi

  pushd "$target_dir" >/dev/null
  if [[ -f config.def.h ]] && [[ ! -f config.h ]]; then
    cp -f config.def.h config.h
  fi

  if [[ -n "$config_source" && -f "$config_source" ]]; then
    cp -f "$config_source" config.h
  else
    log_warn "Custom config not found for $repo_name at $config_source"
  fi

  sudo make clean install
  popd >/dev/null

  log_success "$repo_name installed"
}

log_step "Installing core packages"
install_packages \
  git base-devel wget curl btop mc fastfetch neovim \
  xorg-server xorg-xinit xorg-xsetroot libx11 libxft libxinerama \
  ttf-dejavu ttf-liberation noto-fonts ttf-hack ttf-font-awesome \
  feh thunar ranger chromium nano vim code obsidian slock conky ly
log_success "Core packages installed"

log_step "Preparing suckless directory"
mkdir -p "$HOME/suckless"

log_step "Preparing ~/.local/bin"
local_bin_dir="$HOME/.local/bin"
powermenu_source="$SCRIPT_DIR/configs/powermenu"
powermenu_target="$local_bin_dir/powermenu"
mkdir -p "$local_bin_dir"
if [[ -f "$powermenu_source" ]]; then
  cp -f "$powermenu_source" "$powermenu_target"
  chmod +x "$powermenu_target"
  log_success "powermenu installed to $powermenu_target"
else
  log_warn "powermenu script not found at $powermenu_source"
fi

log_step "Preparing Conky config"
conky_dir="$HOME/.config/conky"
conky_source="$SCRIPT_DIR/configs/conky/config.conf"
conky_target="$conky_dir/config.conf"
mkdir -p "$conky_dir"
if [[ -f "$conky_source" ]]; then
  cp -f "$conky_source" "$conky_target"
  log_success "Conky config copied to $conky_target"
else
  log_warn "Conky config not found at $conky_source"
fi

log_step "Preparing wallpaper directory"
wallpaper_dir="$HOME/Documents/Pictures/Wallpapers"
wallpaper_file="space.jpg"
wallpaper_source="$SCRIPT_DIR/wallpapers/$wallpaper_file"
wallpaper_target="$wallpaper_dir/$wallpaper_file"
mkdir -p "$wallpaper_dir"
if [[ -f "$wallpaper_source" ]]; then
  cp -f "$wallpaper_source" "$wallpaper_target"
  log_success "Wallpaper copied to $wallpaper_target"
else
  log_warn "Wallpaper source not found at $wallpaper_source"
fi

build_and_install dwm
build_and_install st
build_and_install dmenu
build_and_install slstatus

log_step "Creating ~/.xinitrc"
mkdir -p "$HOME"
if [[ ! -f "$HOME/.xinitrc" ]]; then
  cat > "$HOME/.xinitrc" <<EOF
#!/bin/sh
slstatus &
conky -c "$HOME/.config/conky/config.conf" &
feh -bg-fill "$wallpaper_target" &
exec dwm
EOF
else
  if ! grep -q 'slstatus &' "$HOME/.xinitrc"; then
    printf '\n# Added by install.sh\nslstatus &\n' >> "$HOME/.xinitrc"
  fi
  if ! grep -q 'conky -c ' "$HOME/.xinitrc"; then
    printf '\n# Added by install.sh\nconky -c "%s" &\n' "$HOME/.config/conky/config.conf" >> "$HOME/.xinitrc"
  fi
  if ! grep -Eq 'feh .*bg-fill' "$HOME/.xinitrc"; then
    printf '\n# Added by install.sh\nfeh --bg-fill "%s" &\n' "$wallpaper_target" >> "$HOME/.xinitrc"
  fi
  if ! grep -q 'exec dwm' "$HOME/.xinitrc"; then
    printf 'exec dwm\n' >> "$HOME/.xinitrc"
  fi
fi
chmod +x "$HOME/.xinitrc"
log_success "~/.xinitrc ready"

log_step "Configuring Ly tty1 login manager"
if [[ ! -f "$HOME/.bash_profile" ]]; then
  cat > "$HOME/.bash_profile" <<'EOF'
# Prevent tty1 auto-start scripts from interfering with ly
if [[ -n $DISPLAY ]]; then
    return
fi
EOF
else
  if ! grep -q 'Prevent tty1 auto-start scripts from interfering with ly' "$HOME/.bash_profile"; then
    cat >> "$HOME/.bash_profile" <<'EOF'

# Prevent tty1 auto-start scripts from interfering with ly
if [[ -n $DISPLAY ]]; then
    return
fi
EOF
  fi
fi

sudo systemctl disable --now getty@tty1.service || true
sudo systemctl enable --now ly@tty1.service || true
log_success "Ly configured on tty1"

log_step "Removing archconfig repository"
if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" && -d "$SCRIPT_DIR" ]]; then
  cd "$HOME" || true
  rm -rf "$SCRIPT_DIR"
  log_success "Removed repository folder $SCRIPT_DIR"
else
  log_warn "Repository folder $SCRIPT_DIR was not removed"
fi

log_step "Installation complete"
log_info "Starting X session with startx..."

if [[ -z "${DISPLAY-}" ]]; then
  exec startx
else
  log_warn "DISPLAY is already set; X session is likely already running. Skipping startx."
fi


