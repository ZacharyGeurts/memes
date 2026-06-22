#!/usr/bin/env bash
# ammosecurity shared helpers — source from modules, do not execute directly
set -euo pipefail

AMMO_VERSION="${AMMO_VERSION:-1}"
AMMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO_PW="${SUDO_PW:-mememe}"
export HOME="${HOME:-/home/default}"

ammo_log() { printf '[ammo v%s] %s\n' "$AMMO_VERSION" "$*"; }

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
  local pat="$1"
  pkill -f "$pat" 2>/dev/null || true
}