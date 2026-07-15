
# Project-AE Dotfiles

Hyprland dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Preview
## Preview

<div align="center">

<img src="https://github.com/user-attachments/assets/da72d16d-c09d-472b-a39e-5d9845a388cb" width="700">

* *

<br>

<img src="https://github.com/user-attachments/assets/4a17cbba-eece-4141-b0a9-d7c47b8f16d8" width="700">

* *

<br>

<img src="https://github.com/user-attachments/assets/a547811d-32fe-4510-a300-7e243238e260" width="700">

* *

<br>

<img src="https://github.com/user-attachments/assets/1e65f1eb-69a8-417b-9d5b-b9a9f771f763" width="700">

* *

<br>

<img src="https://github.com/user-attachments/assets/4af27a2e-458d-46aa-b5ba-57717a03daeb" width="700">

* *

</div>
## Structure

```
stow/
├── hypr/        # Hyprland WM (lua config)
├── waybar/      # Status bar + 7 themes
├── kitty/       # Terminal emulator
├── fish/        # Shell
├── btop/        # System monitor
├── rofi/        # App launcher + wifi/screenshot/power/theme scripts
├── swaync/      # Notification center
├── waypaper/    # Wallpaper manager
├── eww/         # Widget system (yuck)
├── cava/        # Audio visualizer
├── mpv/         # Media player
├── nwg-bar/     # GTK bar
└── nwg-look/    # GTK settings
```

## Installation Guide

```bash
git clone https://github.com/shivamThebug/Project-AE.git
cd Project-AE
```
```bash
chmod +x ./install.sh
./install.sh
```

This installs all packages (official + AUR) and deploys configs via Stow.

## Manual Deploy

```bash
cd stow
stow -t "$HOME" */
```

## Requirements

See `.requirement` for the full package list.

## Credits

Some scripts in this repo were drafted with AI assistance. If you
recognize a close resemblance to your own work, open an issue and
I'll credit/fix it.
