#!/bin/bash
options="  Lock\n󰈆  Log Out\n󰤄  Suspend\n󰜉  Reboot\n󰐥  Power Off"
chosen=$(echo -e "$options" | rofi -dmenu -hover-select -me-select-entry '' -me-accept-entry MousePrimary -theme ~/.config/rofi/power_menu.rasi)
case "$chosen" in
    *Lock) hyprlock ;;
    *Log*) pkill Hyprland ;;
    *Suspend) systemctl suspend ;;
    *Reboot) systemctl reboot ;;
    *Off) systemctl poweroff ;;
esac