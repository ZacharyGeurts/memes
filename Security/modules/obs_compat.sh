#!/usr/bin/env bash
# obs_compat — OBS Studio PipeWire / portal whitelist helper (AmmoSecurity v2)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

OBS_FLATPAK_ID='com.obsproject.Studio'
OBS_STATE="${AMMO_STATE}/obs_whitelist"

cmd_obs_detect() {
  if command -v flatpak >/dev/null 2>&1 && flatpak info "$OBS_FLATPAK_ID" &>/dev/null; then
    echo "flatpak:$OBS_FLATPAK_ID"
    return 0
  fi
  if command -v obs >/dev/null 2>&1; then
    command -v obs
    return 0
  fi
  return 1
}

cmd_obs_portal_backend() {
  ammo_log 'ensure xdg-desktop-portal + PipeWire backends'
  ammo_sudo apt-get install -y xdg-desktop-portal xdg-desktop-portal-gnome \
    xdg-desktop-portal-wlr pipewire pipewire-pulse 2>/dev/null || true
  systemctl --user start pipewire pipewire-pulse xdg-desktop-portal 2>/dev/null || true
}

cmd_obs_flatpak_perms() {
  command -v flatpak >/dev/null 2>&1 || return 0
  flatpak info "$OBS_FLATPAK_ID" &>/dev/null || return 0
  ammo_log "grant screen capture to $OBS_FLATPAK_ID"
  flatpak permission-set screen-capture screen-capture yes "$OBS_FLATPAK_ID" 2>/dev/null || true
  flatpak override --user "$OBS_FLATPAK_ID" \
    --env=QT_QPA_PLATFORM=wayland \
    --env=XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}" 2>/dev/null || true
}

cmd_obs_native_env() {
  local obs_bin
  obs_bin="$(cmd_obs_detect 2>/dev/null || true)"
  [[ -z "$obs_bin" || "$obs_bin" == flatpak:* ]] && return 0
  ammo_log "native OBS: $obs_bin — use Screen Capture (PipeWire) source"
  mkdir -p "${HOME}/.config/ammo-obs"
  cat >"${HOME}/.config/ammo-obs/env.sh" <<'EOF'
export QT_QPA_PLATFORM=wayland
export OBS_USE_NEW_MPEGTS_OUTPUT=1
EOF
}

cmd_obs_setup() {
  ammo_log '=== OBS compatibility setup ==='
  cmd_obs_portal_backend
  if cmd_obs_detect; then
    ammo_log "OBS found: $(cmd_obs_detect)"
    cmd_obs_flatpak_perms
    cmd_obs_native_env
    ammo_state_ensure
    date -Is 2>/dev/null | ammo_sudo tee "$OBS_STATE" >/dev/null || date >"${HOME}/.local/share/ammosecurity/obs_whitelist" 2>/dev/null || true
    ammo_log 'OBS whitelisted — PipeWire screen capture should work'
  else
    ammo_log 'OBS not installed — flatpak install flathub com.obsproject.Studio'
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_obs_setup "$@"
fi