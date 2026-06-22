#!/usr/bin/env bash
# ammo_gui.sh — pure shell tick-box menu (uses lib/common.sh box + prefs)
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMMO_ROOT="$(cd "$MOD/.." && pwd)"
GUI_AUTOSTART="${HOME}/.config/autostart/ammo-shield.desktop"

export AMOURANTH_BRAND=1

gui_mandatory() {
  ammo_run_module net_harden bash "$MOD/net_harden.sh"
  ammo_run_module service_cleaner bash "$MOD/service_cleaner.sh"
  ammo_run_module clam_purge bash "$MOD/antivirus.sh" -PurgeClam
  ammo_run_module surveillance bash "$MOD/anti_surveillance.sh"
  ammo_run_module fcc bash "$MOD/fcc_guard.sh"
  ammo_run_module dead_air bash "$MOD/dead_air_regulator.sh"
  ammo_run_module human_contact bash "$MOD/human_contact_regulator.sh"
  ammo_run_module screen_guard bash "$MOD/screen_guard.sh" enable
  ammo_run_module watcher bash "$MOD/ammo_watch.sh" install
  ammo_run_module clipboard bash "$AMMO_ROOT/install_clipboard.sh"
}

gui_apply_network() {
  local net vpn
  net="$(ammo_prefs_net_mode)"
  vpn="$(ammo_prefs_read VPN_ONLY 0)"
  export AMMO_VPN_ONLY="$vpn"
  case "$net" in
    wifi)     ammo_run_module net_wifi bash "$MOD/net_mode.sh" wifi --killswitch ;;
    ethernet) ammo_run_module net_eth bash "$MOD/net_mode.sh" ethernet --killswitch ;;
    both)     ammo_run_module net_both bash "$MOD/net_mode.sh" both --killswitch ;;
    *)        ammo_run_module net_airgap bash "$MOD/net_mode.sh" airgap --killswitch ;;
  esac
}

gui_apply_optional() {
  local obs clasp
  obs="$(ammo_prefs_read OBS 0)"
  clasp="$(ammo_prefs_read CLASP_UNLOCK 0)"
  if [[ "$obs" == 1 ]]; then
    ammo_run_module obs bash "$MOD/obs_compat.sh"
  fi
  if [[ "$clasp" == 1 ]]; then
    ammo_run_module ingress_unlock bash "$MOD/ingress_clasp.sh" -Unlock
  else
    ammo_run_module ingress_lock bash "$MOD/ingress_clasp.sh"
  fi
}

gui_apply() {
  gui_mandatory
  gui_apply_network
  gui_apply_optional
}

gui_has_saved_on() {
  grep -qE '^(WIFI|ETHERNET|OBS|CLASP_UNLOCK|VPN_ONLY)=1' "$AMMO_PREFS" 2>/dev/null
}

gui_startup() {
  ammo_clear_screen
  gui_mandatory
  if gui_has_saved_on; then
    gui_apply_network
    gui_apply_optional
  else
    ammo_run_module net_airgap bash "$MOD/net_mode.sh" airgap --killswitch
    ammo_run_module ingress_lock bash "$MOD/ingress_clasp.sh"
  fi
}

gui_draw() {
  local w e obs clasp vpn net prefs_line
  w="$(ammo_prefs_read WIFI 0)"
  e="$(ammo_prefs_read ETHERNET 0)"
  obs="$(ammo_prefs_read OBS 0)"
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
  ammo_box_row '[x]  secure clipboard  ingress clasp LOCKED'
  ammo_box_div
  ammo_box_row 'YOUR TOGGLES  press number to flip'
  ammo_box_row "$(ammo_tick_char "$w")  1  WiFi"
  ammo_box_row "$(ammo_tick_char "$e")  2  Ethernet"
  ammo_box_row "$(ammo_tick_char "$obs")  3  OBS PipeWire (optional)"
  ammo_box_row "$(ammo_tick_char "$vpn")  4  VPN-only egress"
  ammo_box_row "$(ammo_tick_char "$clasp")  5  Ingress unlock (danger)"
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
  ammo_box_row "clip    : mandatory"
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
    4) ammo_prefs_toggle VPN_ONLY; gui_apply ;;
    5)
      if [[ "$(ammo_prefs_read CLASP_UNLOCK 0)" == 1 ]]; then
        ammo_prefs_write CLASP_UNLOCK 0; gui_apply
      elif gui_confirm 'Unlock ingress? Trust your hardware.'; then
        ammo_prefs_write CLASP_UNLOCK 1; gui_apply
      fi
      ;;
    a|A) gui_apply; ammo_log 'applied' ;;
    t|T) gui_apply; gui_test_view ;;
    s|S)
      ammo_clear_screen
      bash "$AMMO_ROOT/ammo.sh" status 2>/dev/null || true
      printf '\n  press Enter: '
      read -r _
      ;;
    r|R) gui_apply; ammo_log 'mandatory refreshed' ;;
    0|q|Q)
      gui_apply
      ammo_clear_screen
      ammo_box_top
      ammo_box_center 'SAVED'
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read WIFI 0)") WiFi  $(ammo_tick_char "$(ammo_prefs_read ETHERNET 0)") Eth"
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read OBS 0)") OBS  [x] Clip"
      ammo_box_row "$(ammo_tick_char "$(ammo_prefs_read CLASP_UNLOCK 0)") Ingress  $(ammo_tick_char "$(ammo_prefs_read VPN_ONLY 0)") VPN"
      ammo_box_row 'You are welcome.'
      ammo_box_bot
      printf '\n'
      return 1
      ;;
    *) printf '\n  use 1-5, a, t, s, r, or 0\n'; sleep 0.6 ;;
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