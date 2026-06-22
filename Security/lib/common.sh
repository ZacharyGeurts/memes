#!/usr/bin/env bash
# Amouranth Shield shared helpers
set -euo pipefail

AMMO_VERSION="${AMMO_VERSION:-2}"
AMMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AMMO_STATE="${AMMO_STATE:-/var/lib/ammosecurity}"
SUDO_PW="${SUDO_PW:-mememe}"
export HOME="${HOME:-/home/default}"
AMOURANTH_TAGLINE="${AMOURANTH_TAGLINE:-glamorous defense, ruthless logic}"

ammo_log() {
  if [[ "${AMOURANTH_BRAND:-}" == 1 ]]; then
    printf '◆ Amouranth Shield │ %s\n' "$*"
  else
    printf '[ammo v%s] %s\n' "$AMMO_VERSION" "$*"
  fi
}

ammo_tip() {
  printf '  → %s\n' "$*"
}

ammo_sudo() {
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

ammo_kill_pattern() {
  pkill -f "$1" 2>/dev/null || true
}

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

ammo_detect_wifi_ifaces() {
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^wl|^wlan' || true
}

ammo_detect_eth_ifaces() {
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^en|^eth' || true
}

ammo_nft_available() {
  command -v nft >/dev/null 2>&1
}

ammo_state_read() {
  local key="$1"
  local f="${AMMO_STATE}/${key}"
  if [[ -f "$f" ]]; then
    cat "$f"
    return 0
  fi
  f="${HOME}/.local/share/ammosecurity/${key}"
  [[ -f "$f" ]] && cat "$f" || return 1
}

ammo_iface_is_up() {
  local iface="$1"
  ip link show "$iface" 2>/dev/null | grep -q 'state UP'
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