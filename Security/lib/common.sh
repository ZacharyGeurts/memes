#!/usr/bin/env bash
# Amouranth Shield shared helpers
set -euo pipefail

AMMO_VERSION="${AMMO_VERSION:-2}"
AMMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AMMO_STATE="${AMMO_STATE:-/var/lib/ammosecurity}"
AMMO_PREFS="${AMMO_PREFS:-${HOME}/.config/ammo-shield/prefs}"
AMMO_NFT_TABLE='inet amouranth_shield'
AMMO_NFT_LEGACY='inet ammosecurity'
SUDO_PW="${SUDO_PW:-mememe}"
export HOME="${HOME:-/home/default}"
AMOURANTH_TAGLINE="${AMOURANTH_TAGLINE:-glamorous defense, ruthless logic}"
AMMO_DRY_RUN="${AMMO_DRY_RUN:-0}"
AMMO_VPN_ONLY="${AMMO_VPN_ONLY:-0}"

# 56-col menu borders: rule=54 between corners, inner text=52
readonly AMMO_BOX_RULE_W=54
readonly AMMO_BOX_INNER_W=52

ammo_log() {
  if [[ "${AMOURANTH_BRAND:-}" == 1 ]]; then
    printf '◆ Amouranth Shield │ %s\n' "$*"
  else
    printf '[ammo v%s] %s\n' "$AMMO_VERSION" "$*"
  fi
}

ammo_tip() { printf '  → %s\n' "$*"; }

ammo_sudo() {
  [[ "$AMMO_DRY_RUN" == 1 ]] && return 0
  printf '%s\n' "$SUDO_PW" | sudo -S -p '' "$@" 2>/dev/null || true
}

ammo_need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]] && ! ammo_sudo true; then
    ammo_log "need root or valid SUDO_PW — re-run with sudo"
    return 1
  fi
}

ammo_service_off() {
  local unit="$1"
  ammo_sudo systemctl stop "$unit" 2>/dev/null || true
  ammo_sudo systemctl disable "$unit" 2>/dev/null || true
  ammo_sudo systemctl mask "$unit" 2>/dev/null || true
}

ammo_kill_pattern() { pkill -f "$1" 2>/dev/null || true; }

ammo_state_ensure() {
  ammo_sudo mkdir -p "$AMMO_STATE" 2>/dev/null || mkdir -p "${HOME}/.local/share/ammosecurity" 2>/dev/null || true
}

ammo_log_violation() {
  local msg="$1"
  ammo_state_ensure
  local logfile="${AMMO_STATE}/violations.log"
  [[ -w "$(dirname "$logfile")" ]] 2>/dev/null || logfile="${HOME}/.local/share/ammosecurity/violations.log"
  printf '%s %s\n' "$(date -Is 2>/dev/null || date)" "$msg" >>"$logfile" 2>/dev/null || true
  ammo_log "VIOLATION: $msg"
}

ammo_log_mode_change() {
  local msg="$1"
  ammo_state_ensure
  local logfile="${AMMO_STATE}/mode_changes.log"
  [[ -w "$(dirname "$logfile")" ]] 2>/dev/null || logfile="${HOME}/.local/share/ammosecurity/mode_changes.log"
  printf '%s %s\n' "$(date -Is 2>/dev/null || date)" "$msg" >>"$logfile" 2>/dev/null || true
  ammo_log "$msg"
}

ammo_detect_wifi_ifaces() {
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^wl|^wlan' || true
}

ammo_detect_eth_ifaces() {
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^en|^eth' || true
}

ammo_detect_vpn_ifaces() {
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tun|wg)' || true
}

ammo_nft_available() { command -v nft >/dev/null 2>&1; }

ammo_state_read() {
  local key="$1"
  local f="${AMMO_STATE}/${key}"
  if [[ -f "$f" ]]; then cat "$f"; return 0; fi
  f="${HOME}/.local/share/ammosecurity/${key}"
  [[ -f "$f" ]] && cat "$f" || return 1
}

ammo_iface_is_up() {
  local iface="$1"
  ip link show "$iface" 2>/dev/null | grep -q 'state UP'
}

ammo_wifi_mac_randomize() {
  command -v nmcli >/dev/null 2>&1 || return 0
  local iface
  while IFS= read -r iface; do
    [[ -z "$iface" ]] && continue
    if [[ "$AMMO_DRY_RUN" == 1 ]]; then
      ammo_log "dry-run: wifi MAC randomize $iface"
    else
      ammo_sudo nmcli device set "$iface" wifi.cloned-mac-address random 2>/dev/null || true
      ammo_log "wifi MAC randomize: $iface"
    fi
  done < <(ammo_detect_wifi_ifaces)
}

ammo_portal_revoke_flatpak_capture() {
  local keep="${1:-com.obsproject.Studio}"
  command -v flatpak >/dev/null 2>&1 || return 0
  flatpak permission-list 2>/dev/null | awk -F'[ \t]+' '
    $1 == "screen-capture" && $3 != "" { print $3 }
  ' | sort -u | while read -r app; do
    [[ -z "$app" || "$app" == "$keep" ]] && continue
    flatpak permission-set screen-capture screen-capture no "$app" 2>/dev/null || true
    ammo_log "revoked screen-capture: $app"
  done
}

# ── prefs (~/.config/ammo-shield/prefs) ───────────────────────────
ammo_prefs_init() {
  mkdir -p "$(dirname "$AMMO_PREFS")" 2>/dev/null || true
  if [[ ! -f "$AMMO_PREFS" ]]; then
    printf '%s\n' \
      '# Amouranth Shield toggles — 0=off 1=on' \
      'WIFI=0' 'ETHERNET=0' 'OBS=0' 'CLIPBOARD=0' 'CLASP_UNLOCK=0' 'VPN_ONLY=0' >"$AMMO_PREFS"
  fi
}

ammo_prefs_read() {
  local key="$1" default="${2:-0}"
  ammo_prefs_init
  local val
  val="$(grep -E "^${key}=" "$AMMO_PREFS" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
  echo "${val:-$default}"
}

ammo_prefs_write() {
  local key="$1" val="$2"
  ammo_prefs_init
  if grep -q "^${key}=" "$AMMO_PREFS" 2>/dev/null; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$AMMO_PREFS"
  else
    echo "${key}=${val}" >>"$AMMO_PREFS"
  fi
}

ammo_prefs_toggle() {
  if [[ "$(ammo_prefs_read "$1" 0)" == 1 ]]; then
    ammo_prefs_write "$1" 0
  else
    ammo_prefs_write "$1" 1
  fi
}

ammo_prefs_net_mode() {
  local w e
  w="$(ammo_prefs_read WIFI 0)"
  e="$(ammo_prefs_read ETHERNET 0)"
  if [[ "$w" == 1 && "$e" == 1 ]]; then echo both
  elif [[ "$w" == 1 ]]; then echo wifi
  elif [[ "$e" == 1 ]]; then echo ethernet
  else echo airgap
  fi
}

# ── 56-column box drawing (pure ASCII width) ───────────────────────
ammo_box_top() {
  local i
  printf '%s' '╔'
  for ((i = 0; i < AMMO_BOX_RULE_W; i++)); do printf '═'; done
  printf '%s\n' '╗'
}

ammo_box_bot() {
  local i
  printf '%s' '╚'
  for ((i = 0; i < AMMO_BOX_RULE_W; i++)); do printf '═'; done
  printf '%s\n' '╝'
}

ammo_box_div() {
  local i
  printf '%s' '╟'
  for ((i = 0; i < AMMO_BOX_RULE_W; i++)); do printf '─'; done
  printf '%s\n' '╢'
}

ammo_box_row() {
  local text="$1"
  if ((${#text} > AMMO_BOX_INNER_W)); then
    text="${text:0:AMMO_BOX_INNER_W}"
  fi
  printf '║ %-*s ║\n' "$AMMO_BOX_INNER_W" "$text"
}

ammo_box_center() {
  local text="$1"
  local n=${#text}
  local pad=$((AMMO_BOX_INNER_W - n))
  local left=$((pad / 2))
  local right=$((pad - left))
  printf '║ %*s%s%*s ║\n' "$left" '' "$text" "$right" ''
}

ammo_tick_char() {
  if [[ "$1" == 1 ]]; then printf '[x]'; else printf '[ ]'; fi
}

ammo_clear_screen() { clear 2>/dev/null || printf '\033[2J\033[H'; }