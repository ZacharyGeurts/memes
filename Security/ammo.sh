#!/usr/bin/env bash
# ammo.sh — Amouranth Shield. Terminal command: ./ammo.sh
set -euo pipefail

export AMOURANTH_BRAND=1
AMMO_VERSION=2
AMMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$AMMO_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
+==========================================================+
|              AMOURANTH SHIELD  |  ammo.sh               |
|         glamorous defense, ruthless logic                |
+==========================================================+

  ./ammo.sh                  tick-box menu (default)
  ./ammo.sh lock             full hardening one shot
  ./ammo.sh unlock           cool down
  ./ammo.sh status           dashboard

  ./ammo.sh net wifi         network modes (--killswitch)
  ./ammo.sh screen on        screen guard
  ./ammo.sh obs              OBS PipeWire setup
  ./ammo.sh watch on         30s re-enforcer
  ./ammo.sh scan             rkhunter/chkrootkit
  ./ammo.sh secure           mandatory + restore ticks
  ./ammo.sh install-gui      desktop + login autostart

  ./ammo.sh clasp | clip | scrub | services | help
  Shortcuts: wifi  eth  airgap  scan

  Toggles saved: ~/.config/ammo-shield/prefs
EOF
}

cmd_gui()       { bash "$AMMO_ROOT/modules/ammo_gui.sh" gui; }
cmd_secure()    { bash "$AMMO_ROOT/modules/ammo_gui.sh" secure; }
cmd_gui_install() { bash "$AMMO_ROOT/modules/ammo_gui.sh" install; }

cmd_smart_tip() {
  local mode screen
  mode="$(ammo_state_read net_mode 2>/dev/null || echo unset)"
  if [[ -f "${AMMO_STATE}/screen_guard" || -f "${HOME}/.local/share/ammosecurity/screen_guard" ]]; then
    screen=on
  else
    screen=off
  fi
  case "$mode:$screen" in
    unset:off) ammo_tip 'Try: ./ammo.sh lock' ;;
    unset:on)  ammo_tip 'Network open — ./ammo.sh net wifi or lock' ;;
    airgap:on) ammo_tip 'Maximum lockdown active.' ;;
    *:off)     ammo_tip "Net: ${mode}. ./ammo.sh screen on" ;;
    *)         ammo_tip "Net: ${mode} · Screen guarded. ./ammo.sh status" ;;
  esac
}

cmd_clipboard() {
  local daemon="${1:-}"
  if [[ "$daemon" == daemon || "$daemon" == -Daemon ]]; then
    local bin="${HOME}/.local/bin/sclipd"
    local svc="${HOME}/.config/systemd/user/sclipd.service"
    ammo_log 'building sclipd vault'
    ammo_sudo apt-get install -y libssl-dev libargon2-dev gcc libseccomp-dev 2>/dev/null || true
    gcc -O3 -fstack-protector-strong -o "$bin" "$AMMO_ROOT/sclipd.c" -lcrypto -largon2 -lseccomp 2>/dev/null || \
      gcc -O3 -o "$bin" "$AMMO_ROOT/sclipd.c" -lcrypto -largon2
    chmod 700 "$bin"
    mkdir -p "$(dirname "$svc")"
    cat >"$svc" <<SVCEOF
[Unit]
Description=Ammo Shield sclipd vault
[Service]
ExecStart=$bin
Restart=on-failure
NoNewPrivs=yes
PrivateTmp=yes
SVCEOF
    systemctl --user daemon-reload
    systemctl --user enable --now sclipd.service
  else
    bash "$AMMO_ROOT/install_clipboard.sh"
  fi
}

cmd_status() {
  ammo_log 'network'
  bash "$AMMO_ROOT/modules/net_mode.sh" status 2>/dev/null || true
  ammo_log 'screen'
  bash "$AMMO_ROOT/modules/screen_guard.sh" status 2>/dev/null || true
  ammo_log 'watcher'
  bash "$AMMO_ROOT/modules/ammo_watch.sh" status 2>/dev/null || true
  ammo_log 'clasp'
  bash "$AMMO_ROOT/modules/ingress_clasp.sh" status 2>/dev/null || true
  bash "$AMMO_ROOT/secure_clipboard.sh" status 2>/dev/null || true
  [[ -f "${AMMO_STATE}/violations.log" ]] && tail -8 "${AMMO_STATE}/violations.log" 2>/dev/null || \
    tail -8 "${HOME}/.local/share/ammosecurity/violations.log" 2>/dev/null || true
  cmd_smart_tip
}

cmd_lock() {
  local mod="$AMMO_ROOT/modules"
  ammo_log 'locking down'
  bash "$mod/net_mode.sh" both --killswitch
  bash "$mod/screen_guard.sh" enable
  bash "$mod/net_harden.sh"
  bash "$mod/service_cleaner.sh"
  bash "$mod/antivirus.sh" -PurgeClam
  bash "$mod/anti_surveillance.sh"
  bash "$mod/fcc_guard.sh"
  bash "$mod/dead_air_regulator.sh"
  bash "$mod/human_contact_regulator.sh"
  bash "$mod/ingress_clasp.sh"
  bash "$mod/ammo_watch.sh" install 2>/dev/null || true
  ammo_log 'locked'
}

cmd_unlock() {
  local mod="$AMMO_ROOT/modules"
  ammo_log 'cooling down'
  bash "$mod/net_mode.sh" both
  bash "$mod/screen_guard.sh" disable
  bash "$mod/ammo_watch.sh" uninstall 2>/dev/null || true
  ammo_sudo nft delete table inet ammosecurity 2>/dev/null || true
  ammo_log 'unlocked — ./ammo.sh lock to re-arm'
}

cmd_all_legacy() {
  bash "$AMMO_ROOT/modules/net_harden.sh"
  bash "$AMMO_ROOT/modules/service_cleaner.sh"
  bash "$AMMO_ROOT/modules/antivirus.sh" $LEGACY_EXTRA
  bash "$AMMO_ROOT/modules/anti_surveillance.sh"
  bash "$AMMO_ROOT/modules/fcc_guard.sh"
  bash "$AMMO_ROOT/modules/dead_air_regulator.sh"
  bash "$AMMO_ROOT/modules/grok_world.sh" "${WORLD_N:-all}"
  bash "$AMMO_ROOT/modules/human_contact_regulator.sh"
  bash "$AMMO_ROOT/modules/ingress_clasp.sh"
  bash "$AMMO_ROOT/modules/scrub_location.sh"
  cmd_clipboard "$LEGACY_EXTRA"
}

map_legacy_action() {
  case "$1" in
    HardAll|hardall)       echo lock ;;
    NetMode|netmode)         echo net ;;
    ScreenHard|screenhard)   echo screen ;;
    OBSSetup|obssetup)       echo obs ;;
    Watch)                   echo watch ;;
    Status|status)           echo status ;;
    All|all)                 echo all ;;
    Antivirus|antivirus)     echo scan ;;
    Net)                     echo net-harden ;;
    Services)                echo services ;;
    Surveillance)            echo surveillance ;;
    FCC)                     echo fcc ;;
    FCCEmissions)            echo fcc-emissions ;;
    DeadAir)                 echo deadair ;;
    World)                   echo world ;;
    HumanContact)            echo human ;;
    Clasp)                   echo clasp ;;
    Clipboard)               echo clip ;;
    Scrub)                   echo scrub ;;
    Help)                    echo help ;;
    *)                       echo "$1" ;;
  esac
}

normalize_screen() {
  case "${1:-status}" in
    on|enable|hard) echo enable ;;
    off|disable)    echo disable ;;
    *)              echo "${1:-status}" ;;
  esac
}

normalize_watch() {
  case "${1:-status}" in
    on|install|enable)       echo install ;;
    off|uninstall|disable)   echo uninstall ;;
    *)                       echo "${1:-status}" ;;
  esac
}

normalize_net_mode() {
  case "${1:-status}" in
    eth|ether)          echo ethernet ;;
    offline|none|gap)     echo airgap ;;
    *)                  echo "${1:-status}" ;;
  esac
}

CMD=''
ARGS=()
LEGACY_EXTRA=''
WORLD_N=''
KILLSWITCH=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Action|-action)
      CMD="$(map_legacy_action "${2:-help}")"
      shift 2
      ;;
    -Install|-Daemon|-Unlock|-PurgeClam)
      LEGACY_EXTRA="$1"
      [[ "$1" == -Unlock ]] && ARGS+=(unlock)
      [[ "$1" == -PurgeClam ]] && CMD=purge-clam
      shift
      ;;
    -N) WORLD_N="${2:-}"; shift 2 ;;
    --killswitch) KILLSWITCH='--killswitch'; shift ;;
    -h|--help|help) CMD=help; shift ;;
    *)
      if [[ -z "$CMD" ]]; then CMD="$1"
      else ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

case "$CMD" in
  wifi)             ARGS=(wifi "${ARGS[@]}"); CMD=net ;;
  eth|ethernet)     ARGS=(ethernet "${ARGS[@]}"); CMD=net ;;
  airgap|offline)   ARGS=(airgap "${ARGS[@]}"); CMD=net ;;
  scan|purge-clam)  ;;
  lock|unlock|status|obs|all|clasp|clip|scrub|services|surveillance|fcc|fcc-emissions|deadair|world|human|net-harden|gui|secure|install-gui|gui-install|help) ;;
  net|screen|watch) ;;
  '')               CMD=gui ;;
  *)                CMD="$(map_legacy_action "$CMD")" ;;
esac

M="$AMMO_ROOT/modules"

case "$CMD" in
  help)           usage; cmd_smart_tip ;;
  gui)            cmd_gui ;;
  secure|boot)    cmd_secure ;;
  install-gui|gui-install) cmd_gui_install ;;
  lock|hardall)   cmd_lock ;;
  unlock)         cmd_unlock ;;
  status)         cmd_status ;;
  net|netmode)    bash "$M/net_mode.sh" "$(normalize_net_mode "${ARGS[0]:-status}")" "$KILLSWITCH" ;;
  screen|screenhard) bash "$M/screen_guard.sh" "$(normalize_screen "${ARGS[0]:-status}")" ;;
  obs|obssetup)   bash "$M/obs_compat.sh" ;;
  watch)          bash "$M/ammo_watch.sh" "$(normalize_watch "${ARGS[0]:-status}")" ;;
  scan|antivirus) bash "$M/antivirus.sh" ${LEGACY_EXTRA:+$LEGACY_EXTRA} ;;
  purge-clam)     bash "$M/antivirus.sh" -PurgeClam ;;
  all)            cmd_all_legacy ;;
  clasp)
    if [[ "${ARGS[0]:-}" == unlock || "$LEGACY_EXTRA" == -Unlock ]]; then
      bash "$M/ingress_clasp.sh" -Unlock
    else
      bash "$M/ingress_clasp.sh" "${LEGACY_EXTRA:--lock}"
    fi
    ;;
  clip|clipboard) cmd_clipboard "${ARGS[0]:-$LEGACY_EXTRA}" ;;
  scrub)          bash "$M/scrub_location.sh" ;;
  net-harden)     bash "$M/net_harden.sh" ;;
  services)       bash "$M/service_cleaner.sh" ;;
  surveillance)   bash "$M/anti_surveillance.sh" ;;
  fcc)            bash "$M/fcc_guard.sh" ;;
  fcc-emissions)  bash "$M/fcc_emissions_regulator.sh" ;;
  deadair)        bash "$M/dead_air_regulator.sh" ;;
  world)          bash "$M/grok_world.sh" "${WORLD_N:-${ARGS[0]:-all}}" ;;
  human)          bash "$M/human_contact_regulator.sh" ;;
  *)
    ammo_log "unknown: $CMD — run ./ammo.sh help"
    usage
    exit 1
    ;;
esac