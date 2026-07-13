#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGES=(
    # Hyprland ecosystem
    hyprland hyprlock hypridle hyprpaper
    waybar rofi swaync
    nwg-bar nwg-look stow

    # Terminal & shell
    kitty fish btop cava

    # Apps & utilities
    dolphin chromium pavucontrol brightnessctl playerctl
    wireplumber pipewire-pulse networkmanager
    grim slurp wl-clipboard jq

    # Fonts
    ttf-jetbrains-mono-nerd noto-fonts-emoji ttf-font-awesome
)

AUR_PACKAGES=(eww waypaper hyprshutdown)

if ! command -v pacman &>/dev/null; then
    echo "Error: This script is Arch-only (pacman required)." >&2
    exit 1
fi

echo "==> Installing official packages..."
sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo "==> Installing AUR packages..."
AUR_FOUND=false
for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
        "$helper" -S --needed --noconfirm "${AUR_PACKAGES[@]}"
        AUR_FOUND=true
        break
    fi
done
if [ "$AUR_FOUND" = false ]; then
    echo "Warning: no AUR helper (yay/paru) found. Install manually:"
    echo "  ${AUR_PACKAGES[*]}"
fi

echo "==> Enabling required services..."
sudo systemctl enable --now NetworkManager

echo "==> Deploying dotfiles with GNU Stow..."
cd "$REPO_DIR/stow"

shopt -s nullglob
for pkg in */; do
    pkg_name="${pkg%/}"

    # Back up any real (non-symlink) existing config directory first
    if [ -d "$HOME/.config/$pkg_name" ] && [ ! -L "$HOME/.config/$pkg_name" ]; then
        echo "Notice: backing up ~/.config/$pkg_name -> ~/.config/${pkg_name}.bak"
        mv "$HOME/.config/$pkg_name" "$HOME/.config/${pkg_name}.bak"
    fi

    stow -R -t "$HOME" "$pkg_name"
    echo "  Stowed: $pkg_name"
done
shopt -u nullglob

echo "==> Dotfiles deployed successfully!"