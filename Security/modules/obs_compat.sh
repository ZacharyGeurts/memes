#!/usr/bin/env bash
# obs_compat — OBS PipeWire / portal whitelist
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

OBS_FLATPAK_ID='com.obsproject.Studio'
OBS_STATE="${AMMO_STATE}/obs_whitelist"
OBS_ENV="${HOME}/.config/ammo-obs/env.sh"

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
  ammo_log 'portal + PipeWire backends'
  ammo_sudo apt-get install -y xdg-desktop-portal xdg-desktop-portal-gnome \
    xdg-desktop-portal-kde xdg-desktop-portal-wlr pipewire pipewire-pulse 2>/dev/null || true
  systemctl --user start pipewire pipewire-pulse xdg-desktop-portal 2>/dev/null || true
}

cmd_obs_flatpak_perms() {
  command -v flatpak >/dev/null 2>&1 || return 0
  flatpak info "$OBS_FLATPAK_ID" &>/dev/null || return 0
  ammo_log "grant screen-capture: $OBS_FLATPAK_ID"
  flatpak permission-set screen-capture screen-capture yes "$OBS_FLATPAK_ID" 2>/dev/null || true
  flatpak override --user "$OBS_FLATPAK_ID" \
    --env=QT_QPA_PLATFORM=wayland \
    --env=XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}" 2>/dev/null || true
}

cmd_obs_native_env() {
  local obs_bin
  obs_bin="$(cmd_obs_detect 2>/dev/null || true)"
  [[ -z "$obs_bin" || "$obs_bin" == flatpak:* ]] && return 0
  ammo_log "native OBS: $obs_bin"
  mkdir -p "$(dirname "$OBS_ENV")"
  cat >"$OBS_ENV" <<'EOF'
export QT_QPA_PLATFORM=wayland
export OBS_USE_NEW_MPEGTS_OUTPUT=1
EOF
  ammo_log "source $OBS_ENV before launching OBS"
}

cmd_obs_whitelist_record() {
  ammo_state_ensure
  printf '%s\n' "$OBS_FLATPAK_ID" 'native-obs' | ammo_sudo tee "${AMMO_STATE}/screen_whitelist" >/dev/null 2>&1 \
    || printf '%s\n' "$OBS_FLATPAK_ID" >"${HOME}/.local/share/ammosecurity/screen_whitelist" 2>/dev/null || true
}

cmd_obs_status() {
  ammo_log 'OBS compatibility status'
  cmd_obs_detect && ammo_log "detected: $(cmd_obs_detect)" || ammo_log 'OBS not installed'
  [[ -f "$OBS_STATE" ]] && ammo_log "whitelisted at: $(cat "$OBS_STATE")"
  [[ -f "$OBS_ENV" ]] && ammo_log "env file: $OBS_ENV"
  systemctl --user is-active pipewire xdg-desktop-portal 2>/dev/null | head -2 || true
}

cmd_obs_setup() {
  ammo_log 'OBS setup — PipeWire screen capture'
  cmd_obs_portal_backend
  if cmd_obs_detect >/dev/null 2>&1; then
    ammo_log "OBS found: $(cmd_obs_detect)"
    cmd_obs_flatpak_perms
    cmd_obs_native_env
    cmd_obs_whitelist_record
    ammo_state_ensure
    date -Is 2>/dev/null | ammo_sudo tee "$OBS_STATE" >/dev/null \
      || date >"${HOME}/.local/share/ammosecurity/obs_whitelist" 2>/dev/null || true
    ammo_log 'OBS whitelisted — add Screen Capture PipeWire source in OBS'
  else
    ammo_log 'install: flatpak install flathub com.obsproject.Studio'
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-setup}" in
    status) cmd_obs_status ;;
    *)      cmd_obs_setup ;;
  esac
fi