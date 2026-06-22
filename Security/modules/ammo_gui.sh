#!/usr/bin/env bash
# ammo_gui.sh — pure shell tick-box menu (uses lib/common.sh box + prefs)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMMO_ROOT="$(cd "$MOD/.." && pwd)"
GUI_AUTOSTART="${HOME}/.config/autostart/ammo-shield.desktop"

export AMOURANTH_BRAND=1

gui_mandatory() {
  bash "$MOD/net_harden.sh" >/dev/null 2>&1 || true
  bash "$MOD/service_cleaner.sh" >/dev/null 2>&1 || true
  bash "$MOD/antivirus.sh" -PurgeClam >/dev/null 2>&1 || true
  bash "$MOD/anti_surveillance.sh" >/dev/null 2>&1 || true
  bash "$MOD/fcc_guard.sh" >/dev/null 2>&1 || true
  bash "$MOD/dead_air_regulator.sh" >/dev/null 2>&1 || true
  bash "$MOD/human_contact_regulator.sh" >/dev/null 2>&1 || true
  bash "$MOD/screen_guard.sh" enable >/dev/null 2>&1 || true
  bash "$MOD/ammo_watch.sh" install >/dev/null 2>&1 || true
}

gui_apply() {
  local net obs clip clasp vpn
  net="$(ammo_prefs_net_mode)"
  obs="$(ammo_prefs_read OBS 0)"
  clip="$(ammo_prefs_read CLIPBOARD 0)"
  clasp="$(ammo_prefs_read CLASP_UNLOCK 0)"
  vpn="$(ammo_prefs_read VPN_ONLY 0)"

  export AMMO_VPN_ONLY="$vpn"
  case "$net" in
    wifi)     bash "$MOD/net_mode.sh" wifi --killswitch ;;
    ethernet) bash "$MOD/net_mode.sh" ethernet --killswitch ;;
    both)     bash "$MOD/net_mode.sh" both --killswitch ;;
    *)        bash "$MOD/net_mode.sh" airgap --killswitch ;;
  esac

  if [[ "$obs" == 1 ]]; then bash "$MOD/obs_compat.sh" >/dev/null 2>&1 || true; fi
  if [[ "$clip" == 1 ]]; then bash "$AMMO_ROOT/install_clipboard.sh" >/dev/null 2>&1 || true; fi
  if [[ "$clasp" == 1 ]]; then
    bash "$MOD/ingress_clasp.sh" -Unlock >/dev/null 2>&1 || true
  else
    bash "$MOD/ingress_clasp.sh" >/dev/null 2>&1 || true
  fi
  gui_mandatory
}

gui_has_saved_on() {
  grep -qE '^(WIFI|ETHERNET|OBS|CLIPBOARD|CLASP_UNLOCK|VPN_ONLY)=1' "$AMMO_PREFS" 2>/dev/null
}

gui_startup() {
  ammo_clear_screen
  gui_mandatory
  if gui_has_saved_on; then
    gui_apply
  else
    bash "$MOD/net_mode.sh" airgap --killswitch >/dev/null 2>&1 || true
    bash "$MOD/ingress_clasp.sh" >/dev/null 2>&1 || true
  fi
}

gui_draw() {
  local w e obs clip clasp vpn net prefs_line
  w="$(ammo_prefs_read WIFI 0)"
  e="$(ammo_prefs_read ETHERNET 0)"
  obs="$(ammo_prefs_read OBS 0)"
  clip="$(ammo_prefs_read CLIPBOARD 0)"
  clasp="$(ammo_prefs_read CLASP_UNLOCK 0)"
  vpn="$(ammo_prefs_read VPN_ONLY 0)"
  net="$(ammo_prefs_net_mode)"
  prefs_line="net: ${net}  vpn-only: ${vpn}"

  ammo_clear_screen
  ammo_box_top
  ammo_box_center 'AMOURANTH SHIELD'
  ammo_box_center "$AMOURANTH_TAGLINE"
  ammo_box_bot
  printf '\n'
  ammo_box_top
  ammo_box_row "$prefs_line"
  ammo_box_div
  ammo_box_row 'MANDATORY  always on'
  ammo_box_row '[x]  firewall  kernel  SMB  ClamAV purge'
  ammo_box_row '[x]  screen guard  watcher  surveillance'
  ammo_box_row '[x]  FCC  dead-air  human-contact  kill-switch'
  ammo_box_div
  ammo_box_row 'YOUR TOGGLES  press number to flip'
  ammo_box_row "$(ammo_tick_char "$w")  1  WiFi"
  ammo_box_row "$(ammo_tick_char "$e")  2  Ethernet"
  ammo_box_row "$(ammo_tick_char "$obs")  3  OBS PipeWire"
  ammo_box_row "$(ammo_tick_char "$clip")  4  Secure clipboard"
  ammo_box_row "$(ammo_tick_char "$clasp")  5  Ingress unlock"
  ammo_box_row "$(ammo_tick_char "$vpn")  6  VPN-only egress"
  ammo_box_div
  ammo_box_row 'a apply  t test  s status  r refresh  0 quit'
  ammo_box_bot
  printf '\n  key: '
}

gui_confirm() {
  local ans
  printf '  %s [y/N]: ' "$1"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

gui_test_view() {
  ammo_box_top
  ammo_box_center 'LIVE TEST'
  ammo_box_div
  ammo_box_row "network : $(ammo_prefs_net_mode)"
  ammo_box_row "wifi    : $(ammo_prefs_read WIFI 0)"
  ammo_box_row "eth     : $(ammo_prefs_read ETHERNET 0)"
  ammo_box_row "obs     : $(ammo_prefs_read OBS 0)"
  ammo_box_row "clip    : $(ammo_prefs_read CLIPBOARD 0)"
  ammo_box_row "ingress : $(ammo_prefs_read CLASP_UNLOCK 0)"
  ammo_box_row "vpn     : $(ammo_prefs_read VPN_ONLY 0)"
  ammo_box_bot
  ip -br link 2>/dev/null | sed 's/^/  /' || true
  printf '\n  You are welcome. We saved your ticks.\n  press Enter: '
  read -r _
}

gui_on_key() {
  local key="$1"
  case "$key" in
    1) ammo_prefs_toggle WIFI; gui_apply ;;
    2) ammo_prefs_toggle ETHERNET; gui_apply ;;
    3) ammo_prefs_toggle OBS; gui_apply ;;
    4) ammo_prefs_toggle CLIPBOARD; gui_apply ;;
    5)
      if [[ "$(ammo_prefs_read CLASP_UNLOCK 0)" == 1 ]]; then
        ammo_prefs_write CLASP_UNLOCK 0; gui_apply
      elif gui_confirm 'Unlock ingress? Trust your hardware.'; then
        ammo_prefs_write CLASP_UNLOCK 1; gui_apply
      fi
      ;;
    6) ammo_prefs_toggle VPN_ONLY; gui_apply ;;
    a|A) gui_apply; ammo_log 'applied' ;;
    t|T) gui_apply; gui_test_view ;;
    s|S)
      ammo_clear_screen
      bash "$AMMO_ROOT/ammo.sh" status 2>/dev/null || true
      printf '\n  press Enter: '
      read -r _
      ;;
    r|R) gui_mandatory; gui_apply; ammo_log 'mandatory refreshed' ;;
    0|q|Q)
      gui_apply
      ammo_clear_screen
      ammo_box_top
      ammo_box_center 'SAVED'
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read WIFI 0)") WiFi  $(ammo_tick_char "$(ammo_prefs_read ETHERNET 0)") Eth"
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read OBS 0)") OBS  $(ammo_tick_char "$(ammo_prefs_read CLIPBOARD 0)") Clip"
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read CLASP_UNLOCK 0)") Ingress  $(ammo_tick_char "$(ammo_prefs_read VPN_ONLY 0)") VPN"
      ammo_box_row 'You are welcome.'
      ammo_box_bot
      printf '\n'
      return 1
      ;;
    *) printf '\n  use 1-6, a, t, s, r, or 0\n'; sleep 0.6 ;;
  esac
  return 0
}

gui_loop() {
  local key
  gui_startup
  while true; do
    gui_draw
    read -r key
    gui_on_key "$key" || break
  done
}

gui_install() {
  mkdir -p "$(dirname "$GUI_AUTOSTART")" "${HOME}/.local/share/applications"
  cat >"$GUI_AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Amouranth Shield
Exec=${AMMO_ROOT}/ammo.sh secure
Terminal=false
X-GNOME-Autostart-enabled=true
Categories=Security;
EOF
  cat >"${HOME}/.local/share/applications/ammo-shield.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Amouranth Shield
Exec=${AMMO_ROOT}/ammo.sh gui
Terminal=true
Categories=Security;
EOF
  ammo_log "installed — prefs: $AMMO_PREFS"
}

cmd_secure() {
  ammo_prefs_init
  gui_mandatory
  gui_apply
  [[ "${1:-}" != quiet ]] && ammo_log 'secure — mandatory on, ticks restored'
}

case "${1:-gui}" in
  secure|boot) cmd_secure "${2:-}" ;;
  install)     gui_install ;;
  mandatory)   gui_mandatory ;;
  apply)       gui_apply ;;
  gui|*)       gui_loop ;;
esac