#!/usr/bin/env bash

# ---------------------------------------------------------------------------

set -uo pipefail

### Configuration -------------------------------------------------------------
PROMPT="WiFi"
THEME="$HOME/.config/network/wifi.rasi"   
USE_NERDFONT=true                         
NOTIFY_TIMEOUT=4000                       

# Keybindings (rofi -kb-custom-N syntax)
KB_RESCAN="Alt+r"
KB_DISCONNECT="Alt+d"
KB_SAVED="Alt+s"
KB_FORGET="super+Delete"

### Icons -----------------------------------------------------------------------
if $USE_NERDFONT; then
    ICON_WIFI="󰤨"
    ICON_LOCK=""
    ICON_UNLOCK=""
    ICON_CONNECTED=""
    ICON_REFRESH="󰑐"
    ICON_SAVED=""
    ICON_DISCONNECT="󰤮"
    ICON_INFO=""
    ICON_HIDDEN="󰘓"
    ICON_OFF="󰀝"
    ICON_BACK="󰁍"
    ICON_DELETE="󰆴"
else
    ICON_WIFI="📶"; ICON_LOCK="🔒"; ICON_UNLOCK="🔓"
    ICON_CONNECTED="✓"; ICON_REFRESH="⟳"; ICON_SAVED="★ "
    ICON_DISCONNECT="⏻"; ICON_INFO="ℹ"; ICON_HIDDEN="◌"
    ICON_OFF="✈"; ICON_BACK="←"; ICON_DELETE="🗑"
fi

### State -----------------------------------------------------------------------
ERR_LOG=$(mktemp /tmp/rofi-wifi-XXXXXX)
trap 'rm -f "$ERR_LOG"' EXIT

declare -A NET_SECURITY=()
declare -A NET_SIGNAL=()
declare -A SAVED_PROFILES=()
ACTIVE_SSID=""

### Helpers -----------------------------------------------------------------------

notify() {
    local title="$1" msg="$2" urgency="${3:-normal}" icon="${4:-network-wireless}"
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -t "$NOTIFY_TIMEOUT" -u "$urgency" -i "$icon" "$title" "$msg"
}

die() {
    echo "Error: $1" >&2
    [ -n "$THEME" ] && rofi -theme "$THEME" -e "$1" </dev/null 2>/dev/null || rofi -e "$1" </dev/null 2>/dev/null || true
    exit 1
}

check_deps() {
    command -v nmcli >/dev/null 2>&1 || die "nmcli not found. Install NetworkManager."
    command -v rofi  >/dev/null 2>&1 || die "rofi not found. Install rofi."
    nmcli general status >/dev/null 2>&1 || die "NetworkManager is not running."
}

# BUG FIX: Modified to use '-format i' to return item row index instead of matching text
rofi_cmd() {
    local prompt="$1" mesg="${2:-}"
    local args=(-dmenu -i -p "$prompt" -markup-rows -format i
                -kb-custom-1 "$KB_RESCAN" -kb-custom-2 "$KB_DISCONNECT"
                -kb-custom-3 "$KB_SAVED" -kb-custom-4 "$KB_FORGET")
    [ -n "$mesg" ] && args+=(-mesg "$mesg")
    [ -n "$THEME" ] && args+=(-theme "$THEME")
    rofi "${args[@]}"
}

rofi_input() {
    local prompt="$1" is_password="${2:-false}" mesg="${3:-Press Enter to submit}"
    local args=(-dmenu -i -p "$prompt" -lines 0)
    [ "$is_password" = "true" ] && args+=(-password)
    [ -n "$mesg" ] && args+=(-mesg "$mesg")
    [ -n "$THEME" ] && args+=(-theme "$THEME")
    rofi "${args[@]}"
}

unescape_nmcli() {
    local s="$1"
    s="${s//\\:/:}"
    s="${s//\\\\/\\}"
    printf '%s' "$s"
}

escape_pango() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

get_iface() {
    local connected_iface="" unknown_iface=""
    local line dev rest typ state
    while IFS= read -r line; do
        dev="${line%%:*}"
        rest="${line#*:}"
        typ="${rest%%:*}"
        state="${rest#*:}"
        [ "$typ" = "wifi" ] || continue
        if [[ "$state" == connected* ]]; then
            connected_iface="$dev"
        elif [ -z "$unknown_iface" ]; then
            unknown_iface="$dev"
        fi
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null)
    echo "${connected_iface:-$unknown_iface}"
}

wifi_radio_state() {
    nmcli radio wifi
}

current_ssid() {
    local iface="$1" raw
    raw=$(nmcli -t -f GENERAL.CONNECTION device show "$iface" 2>/dev/null)
    raw="${raw#*:}"
    [ "$raw" = "--" ] && raw=""
    unescape_nmcli "$raw"
}

load_saved_profiles() {
    SAVED_PROFILES=()
    local line ctype name
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ctype="${line%%:*}"
        name="${line#*:}"
        name=$(unescape_nmcli "$name")
        [[ "$ctype" == *wireless* ]] && SAVED_PROFILES["$name"]=1
    done < <(nmcli -t -f TYPE,NAME connection show 2>/dev/null)
}

is_saved_profile() {
    [ -n "${SAVED_PROFILES[$1]:-}" ]
}

### Scanning -----------------------------------------------------------------------

scan_networks() {
    local rescan="${1:-0}"
    local iface
    iface=$(get_iface)

    if [ "$rescan" = "1" ]; then
        nmcli device wifi rescan >/dev/null 2>&1 || true
        sleep 1
    fi

    load_saved_profiles
    NET_SECURITY=(); NET_SIGNAL=(); 

    # BUG FIX: Directly pull active profile from device configuration to guarantee synchronization
    ACTIVE_SSID=$(nmcli -t -f GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -n1 | cut -d: -f2-)
    [ "$ACTIVE_SSID" = "--" ] && ACTIVE_SSID=""
    ACTIVE_SSID=$(unescape_nmcli "$ACTIVE_SSID")

    local line inuse rest1 signal rest2 security ssid_raw ssid
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        inuse="${line%%:*}"
        rest1="${line#*:}"
        signal="${rest1%%:*}"
        rest2="${rest1#*:}"
        security="${rest2%%:*}"
        ssid_raw="${rest2#*:}"
        ssid=$(unescape_nmcli "$ssid_raw")
        [ -z "$ssid" ] && continue

        if [ -z "$ACTIVE_SSID" ] && [ "$inuse" = "*" ]; then
            ACTIVE_SSID="$ssid"
        fi

        if [ -z "${NET_SIGNAL[$ssid]:-}" ] || [ "${signal:-0}" -gt "${NET_SIGNAL[$ssid]}" ]; then
            NET_SIGNAL["$ssid"]="$signal"
            NET_SECURITY["$ssid"]="$security"
        fi
    done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)
}

build_network_menu() {
    local ssid signal security sec_icon mark ssid_disp padded saved_mark line
    local sorted_ssids=()

    while IFS= read -r ssid; do
        sorted_ssids+=("$ssid")
    done < <(for s in "${!NET_SIGNAL[@]}"; do printf '%s\t%s\n' "${NET_SIGNAL[$s]}" "$s"; done | sort -t$'\t' -k1,1nr | cut -f2-)

    for ssid in "${sorted_ssids[@]}"; do
        signal="${NET_SIGNAL[$ssid]:-0}"
        security="${NET_SECURITY[$ssid]:-}"
        sec_icon="$ICON_UNLOCK"
        [ "$security" != "--" ] && [ -n "$security" ] && sec_icon="$ICON_LOCK"

        mark=" "
        ssid_disp=$(escape_pango "$ssid")
        padded=$(printf "%-28.28s" "$ssid_disp")

        saved_mark="  "
        is_saved_profile "$ssid" && saved_mark="${ICON_SAVED} "

        # BUG FIX: Active connection comparison is now completely reliable
        if [ "$ssid" = "$ACTIVE_SSID" ]; then
            mark="$ICON_CONNECTED"
            padded="<b>${padded}</b>"
            sec_icon="$ICON_UNLOCK" # Force active network to display unlocked icon
        fi

        line=$(printf "%s %s %s%s %3s%%" "$mark" "$sec_icon" "$saved_mark" "$padded" "$signal")
        printf '%s\t%s\n' "$line" "$ssid"
    done
}

### Actions -----------------------------------------------------------------------

toggle_wifi_radio() {
    if [ "$(wifi_radio_state)" = "enabled" ]; then
        nmcli radio wifi off
        notify "WiFi" "Radio turned off" normal network-wireless-offline
    else
        nmcli radio wifi on
        notify "WiFi" "Radio turned on"
        sleep 1
    fi
}

disconnect_wifi() {
    local iface="$1" ssid
    ssid=$(current_ssid "$iface")
    if [ -z "$ssid" ]; then
        notify "WiFi" "Not currently connected"
        return
    fi
    if nmcli device disconnect "$iface" >/dev/null 2>&1; then
        notify "WiFi" "Disconnected from ${ssid}" normal network-wireless-disconnected
    else
        notify "WiFi" "Failed to disconnect" critical dialog-error
    fi
}

connect_to_network() {
    local ssid="$1" security attempt pass err

    notify "WiFi" "Connecting to ${ssid}…"

    if is_saved_profile "$ssid"; then
        if nmcli connection up id "$ssid" >"$ERR_LOG" 2>&1; then
            notify "WiFi" "Connected to ${ssid}"
            return 0
        fi
        notify "WiFi" "Saved credentials failed — re-enter password" critical dialog-error
        nmcli connection delete id "$ssid" >/dev/null 2>&1 || true
    fi

    security="${NET_SECURITY[$ssid]:-}"
    if [ "$security" = "--" ] || [ -z "$security" ]; then
        if nmcli device wifi connect "$ssid" >"$ERR_LOG" 2>&1; then
            notify "WiFi" "Connected to ${ssid}"
        else
            err=$(tail -n1 "$ERR_LOG")
            notify "WiFi" "${err:-Failed to connect to ${ssid}}" critical dialog-error
        fi
        return
    fi

    attempt=1
    while [ "$attempt" -le 3 ]; do
        pass=$(rofi_input "Password (${ssid})" "true" "Attempt ${attempt} of 3")
        [ -z "$pass" ] && { notify "WiFi" "Cancelled"; return 1; }

        if nmcli device wifi connect "$ssid" password "$pass" >"$ERR_LOG" 2>&1; then
            notify "WiFi" "Connected to ${ssid}"
            return 0
        fi

        err=$(tail -n1 "$ERR_LOG")
        notify "WiFi" "${err:-Wrong password} (attempt ${attempt}/3)" critical dialog-error
        attempt=$((attempt + 1))
    done

    notify "WiFi" "Giving up on ${ssid} after 3 attempts" critical dialog-error
    return 1
}

connect_hidden_network() {
    local ssid sec_choice pass

    ssid=$(rofi_input "Hidden network SSID" "false" "Type SSID name and press Enter")
    [ -z "$ssid" ] && return

    sec_choice=$(printf "Secured (WPA/WPA2/WPA3)\nOpen (no password)" | rofi_input "Security type" "false" "Select authentication profile")
    [ -z "$sec_choice" ] && return

    if [[ "$sec_choice" == Open* ]]; then
        if nmcli device wifi connect "$ssid" hidden yes >"$ERR_LOG" 2>&1; then
            notify "WiFi" "Connected to ${ssid}"
        else
            notify "WiFi" "$(tail -n1 "$ERR_LOG")" critical dialog-error
        fi
        return
    fi

    pass=$(rofi_input "Password (${ssid})" "true" "Type passphrase and press Enter")
    [ -z "$pass" ] && return

    if nmcli device wifi connect "$ssid" password "$pass" hidden yes >"$ERR_LOG" 2>&1; then
        notify "WiFi" "Connected to ${ssid}"
    else
        notify "WiFi" "$(tail -n1 "$ERR_LOG")" critical dialog-error
    fi
}

show_connection_info() {
    local iface="$1" info line key val
    local conn="" ip="" gw="" dns="" mac="" state=""

    info=$(nmcli -t -f GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.HWADDR,GENERAL.STATE device show "$iface" 2>/dev/null)

    while IFS= read -r line; do
        key="${line%%:*}"
        val="${line#*:}"
        case "$key" in
            GENERAL.CONNECTION) conn="$val" ;;
            IP4.ADDRESS*) ip="$val" ;;
            IP4.GATEWAY) gw="$val" ;;
            IP4.DNS*) dns="${dns:+$dns, }$val" ;;
            GENERAL.HWADDR) mac="$val" ;;
            GENERAL.STATE) state="$val" ;;
        esac
    done <<<"$info"

    local signal="" security="" a r1 s r2 sec ssid
    while IFS= read -r line; do
        a="${line%%:*}"; r1="${line#*:}"
        s="${r1%%:*}"; r2="${r1#*:}"
        sec="${r2%%:*}"
        ssid="${r2#*:}"
        ssid=$(unescape_nmcli "$ssid")
        if [ "$a" = "yes" ] && [ "$ssid" = "$conn" ]; then
            signal="$s"; security="$sec"
        fi
    done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null)

    local text
    text="SSID:      ${conn:-N/A}
State:     ${state:-N/A}
Signal:    ${signal:-N/A}%
Security:  ${security:-N/A}
IP:        ${ip:-N/A}
Gateway:   ${gw:-N/A}
DNS:       ${dns:-N/A}
MAC:       ${mac:-N/A}"

    [ -n "$THEME" ] && rofi -theme "$THEME" -e "$text" </dev/null || rofi -e "$text" </dev/null
}

### Menus -----------------------------------------------------------------------

saved_networks_menu() {
    local menu_lines=()
    local menu_names=()
    local line ctype name mark auto auto_tag disp entry_line

    while IFS= read -r line; do
        ctype="${line%%:*}"
        name="${line#*:}"
        name=$(unescape_nmcli "$name")
        [[ "$ctype" == *wireless* ]] || continue

        mark=" "
        [ "$name" = "$ACTIVE_SSID" ] && mark="$ICON_CONNECTED"

        auto=$(nmcli -g connection.autoconnect connection show id "$name" 2>/dev/null)
        auto_tag=""
        [ "$auto" = "yes" ] && auto_tag=" (auto)"

        disp=$(escape_pango "$name")
        [ "$mark" = "$ICON_CONNECTED" ] && disp="<b>${disp}</b>"

        entry_line="$mark  ${disp}${auto_tag}"
        menu_lines+=("$entry_line")
        menu_names+=("$name")
    done < <(nmcli -t -f TYPE,NAME connection show 2>/dev/null)

    if [ "${#menu_lines[@]}" -eq 0 ]; then
        [ -n "$THEME" ] && rofi -theme "$THEME" -e "No saved WiFi networks." </dev/null || rofi -e "No saved WiFi networks." </dev/null
        return
    fi

    menu_lines+=("${ICON_BACK} Back")
    menu_names+=("__BACK__")

    local choice_idx rc
    choice_idx=$(printf '%s\n' "${menu_lines[@]}" | rofi_cmd "Saved Networks" "Enter connect · Delete forget · Alt+s autoconnect · Alt+d disconnect")
    rc=$?

    if [ $rc -eq 1 ] || [ -z "$choice_idx" ]; then
        return
    fi

    local name="${menu_names[$choice_idx]}"

    case $rc in
        10) saved_networks_menu; return ;;
        11)
            if [ -n "$name" ] && [ "$name" = "$ACTIVE_SSID" ]; then
                nmcli device disconnect "$(get_iface)" >/dev/null 2>&1
                notify "WiFi" "Disconnected from ${name}"
            fi
            saved_networks_menu; return ;;
        12)
            [ "$name" = "__BACK__" ] && { saved_networks_menu; return; }
            local cur
            cur=$(nmcli -g connection.autoconnect connection show id "$name" 2>/dev/null)
            if [ "$cur" = "yes" ]; then
                nmcli connection modify id "$name" connection.autoconnect no
                notify "WiFi" "Autoconnect disabled for ${name}"
            else
                nmcli connection modify id "$name" connection.autoconnect yes
                notify "WiFi" "Autoconnect enabled for ${name}"
            fi
            saved_networks_menu; return ;;
        13)
            [ "$name" = "__BACK__" ] && { saved_networks_menu; return; }
            nmcli connection delete id "$name" >/dev/null 2>&1 \
                && notify "WiFi" "${ICON_DELETE} Forgot ${name}" \
                || notify "WiFi" "Failed to remove ${name}" critical dialog-error
            saved_networks_menu; return ;;
    esac

    [ "$name" = "__BACK__" ] && return

    nmcli connection up id "$name" >/dev/null 2>&1 \
        && notify "WiFi" "Connected to ${name}" \
        || notify "WiFi" "Failed to connect to ${name}" critical dialog-error
}

main_menu() {
    local iface radio
    iface=$(get_iface)
    [ -z "$iface" ] && die "No WiFi interface found."

    radio=$(wifi_radio_state)
    if [ "$radio" != "enabled" ]; then
        local choice
        choice=$(printf "%s  Enable WiFi\n%s  Quit" "$ICON_WIFI" "$ICON_BACK" \
            | rofi_input "$PROMPT" "false" "WiFi radio is currently disabled")
        if [[ "$choice" == *"Enable WiFi" ]]; then
            toggle_wifi_radio
            main_menu
        fi
        return
    fi

    scan_networks 0

    local menu_lines=()
    local menu_ssids=()
    local disp ssid

    while IFS=$'\t' read -r disp ssid; do
        menu_lines+=("$disp")
        menu_ssids+=("$ssid")
    done < <(build_network_menu)

    local hidden_entry="${ICON_HIDDEN}  Connect to hidden network"
    local saved_entry="${ICON_SAVED}  Saved networks"
    local rescan_entry="${ICON_REFRESH}  Rescan"
    local off_entry="${ICON_OFF}  Turn WiFi off"
    local info_entry="${ICON_INFO}  Connection info"

    menu_lines+=("$hidden_entry"); menu_ssids+=("__HIDDEN__")
    menu_lines+=("$saved_entry");  menu_ssids+=("__SAVED__")
    menu_lines+=("$rescan_entry"); menu_ssids+=("__RESCAN__")
    menu_lines+=("$off_entry");    menu_ssids+=("__OFF__")
    [ -n "$ACTIVE_SSID" ] && { menu_lines+=("$info_entry"); menu_ssids+=("__INFO__"); }

    local mesg
    if [ -n "$ACTIVE_SSID" ]; then
        mesg="Connected: ${ACTIVE_SSID}  ·  Alt+r rescan  ·  Alt+d disconnect  ·  Alt+s saved  ·  Del forget"
    else
        mesg="Not connected  ·  Alt+r rescan  ·  Alt+s saved networks"
    fi

    local choice_idx rc
    choice_idx=$(printf '%s\n' "${menu_lines[@]}" | rofi_cmd "$PROMPT" "$mesg")
    rc=$?

    if [ $rc -eq 1 ] || [ -z "$choice_idx" ]; then
        return
    fi

    # BUG FIX: Handlers now target explicit indexed rows cleanly
    case $rc in
        10) 
            scan_networks 1
            main_menu; return ;;
        11) disconnect_wifi "$iface"; main_menu; return ;;
        12) saved_networks_menu; main_menu; return ;;
        13)
            ssid="${menu_ssids[$choice_idx]}"
            if [[ "$ssid" != __* ]] && is_saved_profile "$ssid"; then
                nmcli connection delete id "$ssid" >/dev/null 2>&1
                notify "WiFi" "${ICON_DELETE} Forgot ${ssid}"
            fi
            main_menu; return ;;
    esac

    ssid="${menu_ssids[$choice_idx]}"

    case "$ssid" in
        "__HIDDEN__") connect_hidden_network; main_menu ;;
        "__SAVED__") saved_networks_menu; main_menu ;;
        "__RESCAN__") scan_networks 1; main_menu ;;
        "__OFF__") toggle_wifi_radio; main_menu ;;
        "__INFO__") show_connection_info "$iface"; main_menu ;;
        *)
            if [ -z "$ssid" ]; then
                main_menu
                return
            fi
            
            if [ "$ssid" = "$ACTIVE_SSID" ]; then
                # BUG FIX: Accurate match now ensures this block executes flawlessly 
                local sub_idx
                sub_idx=$(printf "Disconnect\nForget Network\nCancel" | rofi_cmd "$ssid" "Network \"$ssid\" is already connected")
                case "$sub_idx" in
                    0) # Disconnect
                        disconnect_wifi "$iface"
                        ;;
                    1) # Forget Network
                        nmcli connection delete id "$ssid" >/dev/null 2>&1
                        notify "WiFi" "${ICON_DELETE} Forgot ${ssid}"
                        ;;
                esac
            else
                connect_to_network "$ssid"
            fi
            main_menu
            ;;
    esac
}

### Entry point -----------------------------------------------------------------------
check_deps
main_menu