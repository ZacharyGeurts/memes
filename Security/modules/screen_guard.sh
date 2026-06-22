#!/usr/bin/env bash
# screen_guard — portal permissions + capture process watch
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCREEN_STATE="${AMMO_STATE}/screen_guard"
SCREEN_WHITELIST="${AMMO_STATE}/screen_whitelist"
CAPTURE_BLOCK_PROCS=(
  scrot import gnome-screenshot spectacle flameshot maim grim
  wf-recorder ksnip deepin-screenshot satty
)

cmd_screen_enable() {
  ammo_log 'screen_guard: enable — revoke capture, block tools'
  ammo_portal_revoke_flatpak_capture 'com.obsproject.Studio'
  local name
  for name in "${CAPTURE_BLOCK_PROCS[@]}"; do
    pkill -x "$name" 2>/dev/null || true
  done
  ammo_state_ensure
  echo enabled | ammo_sudo tee "$SCREEN_STATE" >/dev/null 2>&1 \
    || echo enabled >"${HOME}/.local/share/ammosecurity/screen_guard" 2>/dev/null || true
  ammo_log 'screen guard active — run ./ammo.sh obs for recording'
}

cmd_screen_disable() {
  ammo_log 'screen_guard: disable'
  ammo_sudo rm -f "$SCREEN_STATE" 2>/dev/null \
    || rm -f "${HOME}/.local/share/ammosecurity/screen_guard" 2>/dev/null || true
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
  pgrep -af 'ffmpeg.*x11grab' 2>/dev/null | grep -vi obs | while read -r line; do
    ammo_log_violation "ffmpeg x11grab: $line"
    pkill -f 'ffmpeg.*x11grab' 2>/dev/null || true
  done
}

cmd_screen_status() {
  if [[ -f "$SCREEN_STATE" || -f "${HOME}/.local/share/ammosecurity/screen_guard" ]]; then
    ammo_log 'screen_guard: ENABLED'
  else
    ammo_log 'screen_guard: disabled'
  fi
  [[ -f "$SCREEN_WHITELIST" ]] && ammo_log "whitelist: $(cat "$SCREEN_WHITELIST" 2>/dev/null | tr '\n' ' ')"
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