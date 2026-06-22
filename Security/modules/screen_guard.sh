#!/usr/bin/env bash
# screen_guard — Wayland portal screen capture hardening + OBS whitelist (v2)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCREEN_STATE="${AMMO_STATE}/screen_guard"
CAPTURE_BLOCK_PROCS=(scrot import gnome-screenshot spectacle flameshot maim)

cmd_screen_enable() {
  ammo_log 'screen_guard: enable — revoke default capture, whitelist OBS'
  bash "$MOD/obs_compat.sh"
  ammo_portal_revoke_flatpak_capture 'com.obsproject.Studio'
  for name in "${CAPTURE_BLOCK_PROCS[@]}"; do
    pkill -x "$name" 2>/dev/null || true
  done
  ammo_state_ensure
  echo enabled | ammo_sudo tee "$SCREEN_STATE" >/dev/null 2>&1 || echo enabled >"${HOME}/.local/share/ammosecurity/screen_guard" 2>/dev/null || true
  ammo_log 'unauthorized capture tools killed; OBS whitelisted via OBSSetup'
}

cmd_screen_disable() {
  ammo_log 'screen_guard: disable'
  ammo_sudo rm -f "$SCREEN_STATE" 2>/dev/null || rm -f "${HOME}/.local/share/ammosecurity/screen_guard" 2>/dev/null || true
}

cmd_screen_watch() {
  [[ -f "$SCREEN_STATE" || -f "${HOME}/.local/share/ammosecurity/screen_guard" ]] || return 0
  local name
  for name in "${CAPTURE_BLOCK_PROCS[@]}"; do
    if pgrep -x "$name" >/dev/null 2>&1; then
      pkill -x "$name" 2>/dev/null || true
      ammo_log_violation "blocked capture tool: $name"
    fi
  done
  # Block rogue ffmpeg x11grab (not OBS)
  pgrep -af 'ffmpeg.*x11grab' 2>/dev/null | grep -v obs | while read -r line; do
    ammo_log_violation "ffmpeg x11grab: $line"
    pkill -f 'ffmpeg.*x11grab' 2>/dev/null || true
  done
}

cmd_screen_status() {
  if [[ -f "$SCREEN_STATE" ]]; then
    ammo_log "screen_guard: ENABLED ($(cat "$SCREEN_STATE"))"
  elif [[ -f "${HOME}/.local/share/ammosecurity/screen_guard" ]]; then
    ammo_log "screen_guard: ENABLED (user state)"
  else
    ammo_log 'screen_guard: disabled'
  fi
  command -v flatpak >/dev/null && flatpak info com.obsproject.Studio 2>/dev/null | head -3 || true
  [[ -f "${AMMO_STATE}/violations.log" ]] && tail -5 "${AMMO_STATE}/violations.log" 2>/dev/null || true
}

cmd_screen_guard() {
  local action="${1:-status}"
  case "$action" in
    enable|on)   cmd_screen_enable ;;
    disable|off) cmd_screen_disable ;;
    watch)       cmd_screen_watch ;;
    obs-setup)   bash "$MOD/obs_compat.sh" ;;
    status|*)    cmd_screen_status; cmd_screen_watch ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_screen_guard "$@"
fi