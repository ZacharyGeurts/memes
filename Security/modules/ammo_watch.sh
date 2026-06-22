#!/usr/bin/env bash
# ammo_watch — background re-enforcement for net_mode + screen_guard (v2 Phase 2)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMMO_ROOT="$(cd "$MOD/.." && pwd)"

WATCH_SVC="${HOME}/.config/systemd/user/ammosecurity-watch.service"
WATCH_TMR="${HOME}/.config/systemd/user/ammosecurity-watch.timer"

cmd_watch_run() {
  bash "$MOD/net_mode.sh" watch 2>/dev/null || true
  bash "$MOD/screen_guard.sh" watch 2>/dev/null || true
}

cmd_watch_install() {
  mkdir -p "$(dirname "$WATCH_SVC")"
  cat >"$WATCH_SVC" <<EOF
[Unit]
Description=AmmoSecurity v2 enforcement watcher
After=network.target

[Service]
Type=oneshot
ExecStart=$MOD/ammo_watch.sh run
EOF
  cat >"$WATCH_TMR" <<EOF
[Unit]
Description=Re-enforce AmmoSecurity net + screen rules every 30s

[Timer]
OnBootSec=45
OnUnitActiveSec=30
AccuracySec=5

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now ammosecurity-watch.timer
  ammo_log "watcher installed: systemctl --user status ammosecurity-watch.timer"
}

cmd_watch_uninstall() {
  systemctl --user disable --now ammosecurity-watch.timer 2>/dev/null || true
  rm -f "$WATCH_SVC" "$WATCH_TMR"
  systemctl --user daemon-reload 2>/dev/null || true
  ammo_log 'watcher removed'
}

cmd_watch_status() {
  systemctl --user is-active ammosecurity-watch.timer 2>/dev/null || ammo_log 'timer: inactive'
  systemctl --user status ammosecurity-watch.timer --no-pager 2>/dev/null | head -8 || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-status}" in
    run)        cmd_watch_run ;;
    install)    cmd_watch_install ;;
    uninstall)  cmd_watch_uninstall ;;
    status|*)   cmd_watch_status ;;
  esac
fi