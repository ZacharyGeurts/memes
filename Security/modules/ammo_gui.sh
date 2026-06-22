#!/usr/bin/env bash
# ammo_gui.sh — pure shell tick-box menu. Fixed width. Prefs remembered.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMMO_ROOT="$(cd "$MOD/.." && pwd)"
AMMO_CFG="${HOME}/.config/ammo-shield"
GUI_PREFS="${AMMO_CFG}/prefs"
GUI_AUTOSTART="${HOME}/.config/autostart/ammo-shield.desktop"

export AMOURANTH_BRAND=1

# Border math: total line = 56 chars
#   corner(1) + rule(54) + corner(1) = 56
#   side(1) + space(1) + text(52) + space(1) + side(1) = 56
readonly GUI_RULE_W=54
readonly GUI_INNER_W=52

gui_box_top() {
  local i
  printf '%s' '╔'
  for ((i = 0; i < GUI_RULE_W; i++)); do printf '═'; done
  printf '%s\n' '╗'
}

gui_box_bot() {
  local i
  printf '%s' '╚'
  for ((i = 0; i < GUI_RULE_W; i++)); do printf '═'; done
  printf '%s\n' '╝'
}

gui_box_div() {
  local i
  printf '%s' '╟'
  for ((i = 0; i < GUI_RULE_W; i++)); do printf '─'; done
  printf '%s\n' '╢'
}

gui_box_row() {
  local text="$1"
  if ((${#text} > GUI_INNER_W)); then
    text="${text:0:GUI_INNER_W}"
  fi
  printf '║ %-*s ║\n' "$GUI_INNER_W" "$text"
}

gui_box_center() {
  local text="$1"
  local n=${#text}
  local pad=$((GUI_INNER_W - n))
  local left=$((pad / 2))
  local right=$((pad - left))
  printf '║ %*s%s%*s ║\n' "$left" '' "$text" "$right" ''
}

gui_clear() { clear 2>/dev/null || printf '\033[2J\033[H'; }

gui_tick_char() {
  if [[ "$1" == 1 ]]; then printf '[x]'; else printf '[ ]'; fi
}

# ── prefs ─────────────────────────────────────────────────────────
gui_prefs_init() {
  mkdir -p "$AMMO_CFG" 2>/dev/null || true
  if [[ ! -f "$GUI_PREFS" ]]; then
    printf '%s\n' \
      '# ammo-shield toggles — 0=off 1=on' \
      'WIFI=0' 'ETHERNET=0' 'OBS=0' 'CLIPBOARD=0' 'CLASP_UNLOCK=0' >"$GUI_PREFS"
  fi
}

gui_prefs_read() {
  local key="$1" default="${2:-0}"
  gui_prefs_init
  local val
  val="$(grep -E "^${key}=" "$GUI_PREFS" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
  echo "${val:-$default}"
}

gui_prefs_write() {
  local key="$1" val="$2"
  gui_prefs_init
  if grep -q "^${key}=" "$GUI_PREFS" 2>/dev/null; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$GUI_PREFS"
  else
    echo "${key}=${val}" >>"$GUI_PREFS"
  fi
}

gui_prefs_toggle() {
  if [[ "$(gui_prefs_read "$1" 0)" == 1 ]]; then
    gui_prefs_write "$1" 0
  else
    gui_prefs_write "$1" 1
  fi
}

gui_net_mode() {
  local w e
  w="$(gui_prefs_read WIFI 0)"
  e="$(gui_prefs_read ETHERNET 0)"
  if [[ "$w" == 1 && "$e" == 1 ]]; then echo both
  elif [[ "$w" == 1 ]]; then echo wifi
  elif [[ "$e" == 1 ]]; then echo ethernet
  else echo airgap
  fi
}

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
  local net obs clip clasp
  net="$(gui_net_mode)"
  obs="$(gui_prefs_read OBS 0)"
  clip="$(gui_prefs_read CLIPBOARD 0)"
  clasp="$(gui_prefs_read CLASP_UNLOCK 0)"

  case "$net" in
    wifi)     bash "$MOD/net_mode.sh" wifi --killswitch ;;
    ethernet) bash "$MOD/net_mode.sh" ethernet --killswitch ;;
    both)     bash "$MOD/net_mode.sh" both --killswitch ;;
    *)        bash "$MOD/net_mode.sh" airgap --killswitch ;;
  esac

  if [[ "$obs" == 1 ]]; then
    bash "$MOD/obs_compat.sh" >/dev/null 2>&1 || true
  fi
  if [[ "$clip" == 1 ]]; then
    bash "$AMMO_ROOT/install_clipboard.sh" >/dev/null 2>&1 || true
  fi
  if [[ "$clasp" == 1 ]]; then
    bash "$MOD/ingress_clasp.sh" -Unlock >/dev/null 2>&1 || true
  else
    bash "$MOD/ingress_clasp.sh" >/dev/null 2>&1 || true
  fi
  gui_mandatory
}

gui_has_saved_on() {
  grep -qE '^(WIFI|ETHERNET|OBS|CLIPBOARD|CLASP_UNLOCK)=1' "$GUI_PREFS" 2>/dev/null
}

gui_startup() {
  gui_clear
  gui_mandatory
  if [[ -f "$GUI_PREFS" ]] && gui_has_saved_on; then
    gui_apply
  else
    bash "$MOD/net_mode.sh" airgap --killswitch >/dev/null 2>&1 || true
    bash "$MOD/ingress_clasp.sh" >/dev/null 2>&1 || true
  fi
}

gui_draw() {
  local w e obs clip clasp net
  w="$(gui_prefs_read WIFI 0)"
  e="$(gui_prefs_read ETHERNET 0)"
  obs="$(gui_prefs_read OBS 0)"
  clip="$(gui_prefs_read CLIPBOARD 0)"
  clasp="$(gui_prefs_read CLASP_UNLOCK 0)"
  net="$(gui_net_mode)"

  gui_clear
  gui_box_top
  gui_box_center 'AMOURANTH SHIELD'
  gui_box_center 'glamorous defense, ruthless logic'
  gui_box_bot
  printf '\n'
  gui_box_top
  gui_box_row "network: ${net}   prefs: ${GUI_PREFS}"
  gui_box_div
  gui_box_row 'MANDATORY  always on'
  gui_box_row '[x]  firewall  kernel  SMB  ClamAV purge'
  gui_box_row '[x]  screen guard  watcher  surveillance'
  gui_box_row '[x]  FCC  dead-air  human-contact  kill-switch'
  gui_box_div
  gui_box_row 'YOUR TOGGLES  press number to flip'
  gui_box_row "$(gui_tick_char "$w")  1  WiFi"
  gui_box_row "$(gui_tick_char "$e")  2  Ethernet"
  gui_box_row "$(gui_tick_char "$obs")  3  OBS PipeWire"
  gui_box_row "$(gui_tick_char "$clip")  4  Secure clipboard"
  gui_box_row "$(gui_tick_char "$clasp")  5  Ingress unlock  USB BT"
  gui_box_div
  gui_box_row 'a apply   t test   s status   r refresh   0 quit'
  gui_box_bot
  printf '\n  key: '
}

gui_confirm() {
  local ans
  printf '  %s [y/N]: ' "$1"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

gui_test_view() {
  local net
  net="$(gui_net_mode)"
  printf '\n'
  gui_box_top
  gui_box_center 'LIVE TEST'
  gui_box_div
  gui_box_row "network mode : ${net}"
  gui_box_row "wifi         : $(gui_prefs_read WIFI 0)"
  gui_box_row "ethernet     : $(gui_prefs_read ETHERNET 0)"
  gui_box_row "obs          : $(gui_prefs_read OBS 0)"
  gui_box_row "clipboard    : $(gui_prefs_read CLIPBOARD 0)"
  gui_box_row "ingress open : $(gui_prefs_read CLASP_UNLOCK 0)"
  gui_box_bot
  ip -br link 2>/dev/null | sed 's/^/  /' || true
  printf '\n  You are welcome. Test your app. We saved your ticks.\n'
  printf '  press Enter: '
  read -r _
}

gui_on_key() {
  local key="$1"
  case "$key" in
    1) gui_prefs_toggle WIFI; gui_apply ;;
    2) gui_prefs_toggle ETHERNET; gui_apply ;;
    3) gui_prefs_toggle OBS; gui_apply ;;
    4) gui_prefs_toggle CLIPBOARD; gui_apply ;;
    5)
      if [[ "$(gui_prefs_read CLASP_UNLOCK 0)" == 1 ]]; then
        gui_prefs_write CLASP_UNLOCK 0
        gui_apply
      elif gui_confirm 'Unlock ingress? Trust your hardware.'; then
        gui_prefs_write CLASP_UNLOCK 1
        gui_apply
      fi
      ;;
    a|A) gui_apply; ammo_log 'applied saved ticks' ;;
    t|T) gui_apply; gui_test_view ;;
    s|S)
      gui_clear
      bash "$AMMO_ROOT/ammo.sh" status 2>/dev/null || true
      printf '\n  press Enter: '
      read -r _
      ;;
    r|R) gui_mandatory; gui_apply; ammo_log 'mandatory refreshed' ;;
    0|q|Q)
      gui_apply
      gui_clear
      gui_box_top
      gui_box_center 'SAVED'
      gui_box_row "$(gui_tick_char "$(gui_prefs_read WIFI 0)") WiFi  $(gui_tick_char "$(gui_prefs_read ETHERNET 0)") Eth"
      gui_box_row "$(gui_tick_char "$(gui_prefs_read OBS 0)") OBS  $(gui_tick_char "$(gui_prefs_read CLIPBOARD 0)") Clip"
      gui_box_row "$(gui_tick_char "$(gui_prefs_read CLASP_UNLOCK 0)") Ingress"
      gui_box_row 'You are welcome.'
      gui_box_bot
      printf '\n'
      return 1
      ;;
    *)
      printf '\n  use 1-5, a, t, s, r, or 0\n'
      sleep 0.6
      ;;
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
Name=Ammo Shield
Exec=${AMMO_ROOT}/ammo.sh secure
Terminal=false
X-GNOME-Autostart-enabled=true
Categories=Security;
EOF
  cat >"${HOME}/.local/share/applications/ammo-shield.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ammo Shield
Exec=${AMMO_ROOT}/ammo.sh gui
Terminal=true
Categories=Security;
EOF
  ammo_log "installed desktop + autostart — prefs: ${GUI_PREFS}"
}

cmd_secure() {
  gui_prefs_init
  gui_mandatory
  gui_apply
  [[ "${1:-}" != quiet ]] && ammo_log 'secure — mandatory on, your ticks restored'
}

case "${1:-gui}" in
  secure|boot) cmd_secure "${2:-}" ;;
  install)     gui_install ;;
  mandatory)   gui_mandatory ;;
  apply)       gui_apply ;;
  gui|*)       gui_loop ;;
esac