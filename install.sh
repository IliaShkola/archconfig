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

  log_step "Building and installing $repo_name"

  if [[ ! -d "$target_dir" ]]; then
    git clone --depth 1 "https://git.suckless.org/$repo_name" "$target_dir"
  else
    log_info "Updating $repo_name"
    git -C "$target_dir" pull --ff-only || true
  fi

  pushd "$target_dir" >/dev/null
  if [[ -f config.def.h ]]; then
    cp -f config.def.h config.h
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
  feh thunar ranger chromium nano vim
log_success "Core packages installed"

log_step "Preparing suckless directory"
mkdir -p "$HOME/suckless"

build_and_install dwm
build_and_install st
build_and_install dmenu
build_and_install slstatus

log_step "Creating ~/.xinitrc"
mkdir -p "$HOME"
if [[ ! -f "$HOME/.xinitrc" ]]; then
  cat > "$HOME/.xinitrc" <<'EOF'
#!/bin/sh
slstatus &
exec dwm
EOF
else
  if ! grep -q 'slstatus &' "$HOME/.xinitrc"; then
    printf '\n# Added by install.sh\nslstatus &\n' >> "$HOME/.xinitrc"
  fi
  if ! grep -q 'exec dwm' "$HOME/.xinitrc"; then
    printf 'exec dwm\n' >> "$HOME/.xinitrc"
  fi
fi
chmod +x "$HOME/.xinitrc"
log_success "~/.xinitrc ready"

log_step "Configuring automatic startx for tty1"
if [[ ! -f "$HOME/.bash_profile" ]]; then
  cat > "$HOME/.bash_profile" <<'EOF'
# Auto-start X11 on tty1
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi
EOF
else
  if ! grep -q 'exec startx' "$HOME/.bash_profile"; then
    cat >> "$HOME/.bash_profile" <<'EOF'

# Auto-start X11 on tty1
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx
fi
EOF
  fi
fi
log_success "Automatic startx configured"

log_step "Installation complete"
log_info "Run startx to launch dwm"


